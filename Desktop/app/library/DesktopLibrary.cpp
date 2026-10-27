#include "DesktopLibrary.h"
#include "compat/ExternalGameCatalog.h"
#include "ui/pages/instance/McResolver.h"
#include "ui/pages/instance/McClient.h"
#include <QFile>
#include <memory>
#include <QDir>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QUrl>
#include <QUuid>
#include <QTimer>
#include <QDateTime>
#include <QElapsedTimer>
DesktopLibrary::DesktopLibrary(const QString& directory,Deeraft::ExternalGameCatalog* catalog,QObject* parent):QObject(parent),m_file(directory+"/library.json"),m_catalog(catalog){
 QDir().mkpath(directory);QFile file(m_file);if(file.open(QIODevice::ReadOnly)){QJsonParseError e;auto doc=QJsonDocument::fromJson(file.readAll(),&e);if(e.error==QJsonParseError::NoError&&doc.isObject())m_data=doc.object();else m_error=tr("实例库配置无法读取，请检查 library.json");}
 connect(catalog,&Deeraft::ExternalGameCatalog::rootsChanged,this,&DesktopLibrary::refreshCatalog);
 connect(catalog,&Deeraft::ExternalGameCatalog::versionsChanged,this,&DesktopLibrary::refreshCatalog);
 refreshCatalog();auto timer=new QTimer(this);timer->setInterval(60000);connect(timer,&QTimer::timeout,this,&DesktopLibrary::refreshAllStatuses);timer->start();QTimer::singleShot(1500,this,&DesktopLibrary::refreshAllStatuses);
}
bool DesktopLibrary::commit(QJsonObject next){QSaveFile file(m_file);auto bytes=QJsonDocument(next).toJson();if(!file.open(QIODevice::WriteOnly)||file.write(bytes)!=bytes.size()||!file.commit()){m_error=tr("无法保存实例库配置");emit changed();return false;}m_data=next;m_error.clear();emit changed();return true;}
void DesktopLibrary::setReducedMotion(bool reduced){auto next=m_data;next["reducedMotion"]=reduced;commit(next);}
bool DesktopLibrary::setMetadata(const QString& key,const QVariantMap& value){auto next=m_data;auto map=next.value("metadata").toObject();auto previous=map.value(key).toObject();for(auto it=value.begin();it!=value.end();++it)previous[it.key()]=QJsonValue::fromVariant(it.value());map[key]=previous;next["metadata"]=map;return commit(next);}
bool DesktopLibrary::associate(const QString& server,const QString& instance,const QString& address){if(!address.trimmed().isEmpty()){QUrl url("mc://"+address.trimmed());if(!url.isValid()||url.host().isEmpty()||!url.userInfo().isEmpty()||!url.path().isEmpty()){m_error=tr("服务器地址无效");emit changed();return false;}}auto next=m_data;if(!address.trimmed().isEmpty()){auto addresses=next.value("addresses").toObject();addresses[server]=address.trimmed();next["addresses"]=addresses;}auto links=next.value("links").toObject();links[server]=instance;next["links"]=links;return commit(next);}
void DesktopLibrary::refreshCatalog(){QVariantList rows;for(auto entry:m_catalog->roots()){auto root=entry.toMap();for(auto value:Deeraft::ExternalVersionResolver::scan(root["path"].toString(),root["options"].toMap())){auto row=value.toMap();auto version=row.value("id").toString();row["versionId"]=version;row["id"]="external:"+root["id"].toString()+":"+version;row["rootId"]=root["id"];row["source"]=root["id"];row["sourceName"]=root["path"];row["sourcePath"]=root["path"];row["name"]=row.value("name",version);row["path"]=row["gameDirectory"];row["description"]=row.value("versionJson").toMap().value("id",version);row["external"]=true;rows.append(row);}}m_instances=rows;emit changed();}
QVariantList DesktopLibrary::servers() const{QVariantList rows;for(auto value:m_data.value("servers").toArray()){auto row=value.toObject().toVariantMap();auto status=m_status.value(row["id"].toString(),{{"state","unknown"},{"label",tr("未检测")}});row["status"]=status;rows.append(row);}return rows;}
QString DesktopLibrary::saveServer(const QString& id,const QString& name,const QString& address,const QString& instance){QUrl url("mc://"+address.trimmed());if(name.trimmed().isEmpty()||!url.isValid()||url.host().isEmpty()||!url.userInfo().isEmpty()||!url.path().isEmpty()||url.hasQuery()||url.hasFragment()||url.port(25565)<=0){m_error=tr("请填写名称及有效服务器地址");emit changed();return {};}
 QString key=id.isEmpty()?QUuid::createUuid().toString(QUuid::WithoutBraces):id;auto next=m_data;auto list=next.value("servers").toArray();QJsonArray updated;for(auto value:list)if(value.toObject()["id"].toString()!=key)updated.append(value);updated.append(QJsonObject{{"id",key},{"name",name.trimmed()},{"address",address.trimmed()}});next["servers"]=updated;auto links=next.value("links").toObject();links[key]=instance;next["links"]=links;if(!commit(next))return {};m_requests.remove(key);m_status.remove(key);refreshStatus(key);return key;}
bool DesktopLibrary::removeServer(const QString& id){auto next=m_data;QJsonArray rows;for(auto row:next.value("servers").toArray())if(row.toObject()["id"].toString()!=id)rows.append(row);next["servers"]=rows;auto links=next.value("links").toObject();links.remove(id);next["links"]=links;if(!commit(next))return false;m_requests.remove(id);m_status.remove(id);emit changed();return true;}
void DesktopLibrary::refreshAllStatuses(){for(auto row:servers())refreshStatus(row.toMap().value("id").toString());}
void DesktopLibrary::finishStatus(const QString& id,const QString& epoch,const QVariantMap& status){if(m_requests.value(id)!=epoch)return;m_requests.remove(id);m_status[id]=status;emit changed();}
void DesktopLibrary::refreshStatus(const QString& id){if(m_requests.contains(id))return;QVariantMap row;for(auto item:servers())if(item.toMap()["id"].toString()==id)row=item.toMap();if(row.isEmpty())return;QUrl address("mc://"+row["address"].toString());if(address.host().isEmpty())return;
 QString epoch=QUuid::createUuid().toString();m_requests[id]=epoch;m_status[id]={{"state","checking"},{"label",tr("检测中")}};emit changed();
 auto operation=new QObject(this);auto elapsed=std::make_shared<QElapsedTimer>();elapsed->start();
 auto fail=[this,id,epoch,operation](const QString& reason){finishStatus(id,epoch,{{"state","unavailable"},{"label",tr("查询失败")},{"detail",reason}});operation->deleteLater();};
 auto resolver=new McResolver(operation,address.host(),address.port(25565));connect(resolver,&McResolver::failed,operation,fail);connect(resolver,&McResolver::succeeded,operation,[this,id,epoch,operation,address,elapsed,fail](QString ip,int port){auto client=new McClient(operation,address.host(),ip,port);connect(client,&McClient::failed,operation,[this,id,epoch,operation,client,fail](const QString& reason){if(client->socketError()==QAbstractSocket::ConnectionRefusedError){finishStatus(id,epoch,{{"state","offline"},{"label",tr("离线")},{"detail",reason}});operation->deleteLater();}else fail(reason);});connect(client,&McClient::succeeded,operation,[this,id,epoch,operation,elapsed](QJsonObject data){auto players=data["players"].toObject();QVariantMap status{{"state","online"},{"label",tr("在线")},{"version",data["version"].toObject()["name"].toString()},{"latency",elapsed->elapsed()},{"updated",QDateTime::currentDateTime().toString("HH:mm")}};if(players["online"].isDouble())status["online"]=players["online"].toInt();if(players["max"].isDouble())status["max"]=players["max"].toInt();finishStatus(id,epoch,status);operation->deleteLater();});client->getStatusData();});QTimer::singleShot(10000,operation,[fail]{fail(tr("连接超时"));});resolver->ping();
}
