#include "AppUpdater.h"
#include "DesktopBridge.h"
#include <QNetworkReply>
#include <QJsonDocument>
#include <QCryptographicHash>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QTimer>
#include <QVersionNumber>
#include <QRegularExpression>
#include <openssl/pem.h>
#include <openssl/evp.h>

namespace {const QUrl manifestUrl("http://mc.ainfinitythecoder.cn/downloads/windows/latest.json");}
AppUpdater::AppUpdater(const QString& data,QObject* parent):QObject(parent),m_data(data),m_settings(data+"/desktop.ini",QSettings::IniFormat){
 if(qEnvironmentVariableIsEmpty("DEERAFT_SMOKE_DIR")){
  auto due=[this]{if(automatic()&&m_settings.value("updates/checkedAt").toLongLong()+86400<QDateTime::currentSecsSinceEpoch())check();};
  QTimer::singleShot(15000,this,due);auto timer=new QTimer(this);timer->setInterval(3600000);connect(timer,&QTimer::timeout,this,due);timer->start();
 }
}
QJsonObject AppUpdater::verifyManifest(const QByteArray& envelope,const QByteArray& publicKey,const QString& expectedHost){
 const auto wrapper=QJsonDocument::fromJson(envelope).object();
 const auto payload=QByteArray::fromBase64(wrapper["payload"].toString().toLatin1()),signature=QByteArray::fromBase64(wrapper["signature"].toString().toLatin1());
 auto bio=BIO_new_mem_buf(publicKey.constData(),publicKey.size());auto key=PEM_read_bio_PUBKEY(bio,nullptr,nullptr,nullptr);BIO_free(bio);if(!key)return {};
 auto context=EVP_MD_CTX_new();const bool valid=EVP_DigestVerifyInit(context,nullptr,nullptr,nullptr,key)==1&&EVP_DigestVerify(context,reinterpret_cast<const unsigned char*>(signature.constData()),signature.size(),reinterpret_cast<const unsigned char*>(payload.constData()),payload.size())==1;
 EVP_MD_CTX_free(context);EVP_PKEY_free(key);if(!valid)return {};
 const auto release=QJsonDocument::fromJson(payload).object();const QUrl url(release["url"].toString());
 if(!QRegularExpression("^[0-9]+\\.[0-9]+\\.[0-9]+$").match(release["version"].toString()).hasMatch()||!QRegularExpression("^[0-9a-fA-F]{64}$").match(release["sha256"].toString()).hasMatch()||release["kernel"].toString()!="11.1.1"||release["platform"].toString()!="windows-x64"||release["sha256"].toString().size()!=64||release["size"].toDouble()<=0||release["size"].toDouble()>2147483648.0||!url.isValid()||url.host()!=(expectedHost.isEmpty()?manifestUrl.host():expectedHost)||!url.path().startsWith("/downloads/windows/")||!url.path().endsWith(".exe")||!url.userInfo().isEmpty()||url.hasQuery()||url.hasFragment()||(url.scheme()!="https"&&url.scheme()!="http")||QVersionNumber::fromString(release["version"].toString()).isNull())return {};
 return release;
}
bool AppUpdater::available()const{return QVersionNumber::fromString(latest())>QVersionNumber::fromString(version());}
void AppUpdater::setAutomatic(bool enabled){m_settings.setValue("updates/automatic",enabled);emit changed();}
void AppUpdater::fail(const QString& message){m_output.reset();m_installer.clear();m_status=message;emit changed();emit notice(message);}
void AppUpdater::check(){
 if(busy())return;
 m_settings.setValue("updates/checkedAt",QDateTime::currentSecsSinceEpoch());m_status=tr("正在检查更新");m_progress=0;
 QNetworkRequest request(m_channelUrl);request.setTransferTimeout(15000);request.setRawHeader("Cache-Control","max-age=3600");m_reply=m_network.get(request);emit changed();
 connect(m_reply,&QNetworkReply::readyRead,this,[this]{if(m_reply&&m_reply->bytesAvailable()>65536)m_reply->abort();});
 connect(m_reply,&QNetworkReply::finished,this,[this]{auto reply=m_reply.data();m_reply.clear();const auto bytes=reply->readAll();const bool ok=reply->error()==QNetworkReply::NoError;reply->deleteLater();if(!ok||bytes.size()>65536){fail(tr("检查更新失败，请稍后重试"));return;}QFile key(":/deeraft/update/public.pem");key.open(QIODevice::ReadOnly);const auto release=verifyManifest(bytes,m_testPublicKey.isEmpty()?key.readAll():m_testPublicKey,m_channelUrl.host());if(release.isEmpty()){fail(tr("更新清单验证失败"));return;}m_release=release;m_status=available()?tr("发现新版本 %1").arg(latest()):tr("已是最新版本");emit changed();});
}
void AppUpdater::download(){
 if(busy()||!available())return;
 QDir().mkpath(m_data+"/updates");const auto path=m_data+"/updates/DeeraftApp-"+latest()+"-setup.exe";
 m_output=std::make_unique<QSaveFile>(path);if(!m_output->open(QIODevice::WriteOnly)){fail(tr("无法保存更新安装包"));return;}
 m_status=tr("正在下载安装包");m_progress=0;QNetworkRequest request(QUrl(m_release["url"].toString()));request.setTransferTimeout(30000);m_reply=m_network.get(request);emit changed();
 connect(m_reply,&QNetworkReply::readyRead,this,[this]{const auto bytes=m_reply->readAll();if(!m_output||m_output->size()+bytes.size()>m_release["size"].toDouble()||m_output->write(bytes)!=bytes.size())m_reply->abort();});
 connect(m_reply,&QNetworkReply::downloadProgress,this,[this](qint64 received,qint64){m_progress=received/m_release["size"].toDouble();emit changed();});
 connect(m_reply,&QNetworkReply::finished,this,[this,path]{auto reply=m_reply.data();m_reply.clear();const bool ok=reply->error()==QNetworkReply::NoError;reply->deleteLater();if(!ok||!m_output||m_output->size()!=m_release["size"].toDouble()){fail(tr("更新下载未完成，可重新下载"));return;}if(!m_output->commit()){fail(tr("保存安装包失败"));return;}m_output.reset();QFile file(path);if(!file.open(QIODevice::ReadOnly)){fail(tr("无法读取安装包"));return;}QCryptographicHash hash(QCryptographicHash::Sha256);hash.addData(&file);file.close();if(hash.result().toHex()!=m_release["sha256"].toString().toLatin1().toLower()){QFile::remove(path);fail(tr("安装包校验失败，请重新下载"));return;}m_installer=path;m_status=tr("更新已就绪，重启后安装");emit changed();emit notice(m_status);});
}
void AppUpdater::cancel(){if(m_reply)m_reply->abort();}
void AppUpdater::install(bool gamesRunning){
 if(!ready()||busy())return;
 if(parent())if(auto bridge=parent()->findChild<DesktopBridge*>()){
  for(const auto& row:bridge->instances())gamesRunning|=row.toMap().value("running").toBool();
  const auto states=bridge->externalStates();for(const auto& row:states)gamesRunning|=row.toMap().value("running").toBool();
 }
 if(gamesRunning){emit notice(tr("请先结束游戏，再安装更新"));return;}
 const auto directory=QCoreApplication::applicationDirPath();
 QProcess installer;installer.setProgram(m_installer);installer.setWorkingDirectory(directory);
#ifdef Q_OS_WIN
 installer.setNativeArguments("/S /WAITPID="+QString::number(QCoreApplication::applicationPid())+" /DATADIR=\""+QDir::toNativeSeparators(m_data)+"\" /D="+QDir::toNativeSeparators(directory));
#endif
 if(!installer.startDetached()){fail(tr("无法打开更新安装包"));return;}
 QCoreApplication::quit();
}
