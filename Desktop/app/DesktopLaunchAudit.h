#pragma once
#include "minecraft/MinecraftLoadAndCheck.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/update/LibrariesTask.h"
#include "minecraft/update/AssetUpdateTask.h"
#include "download/ResourceReuseTask.h"
#include "java/JavaInstallList.h"
#include "java/JavaInstall.h"
#include "tasks/SequentialTask.h"
#include <QNetworkProxy>
#include <QTcpServer>
#include <QTcpSocket>

// Explicit, isolated preparation audit: no account, game process, original-directory writes or network downloads.
inline bool startDesktopLaunchAudit(DesktopBridge* bridge,Deeraft::ExternalGameCatalog* catalog,QObject* owner,const QString& output)
{
    const auto root=qEnvironmentVariable("DEERAFT_AUDIT_ROOT");if(root.isEmpty())return false;
    auto report=std::make_shared<QJsonObject>();auto attempts=std::make_shared<int>(0);auto background=std::make_shared<int>(0);
    auto proxy=new QTcpServer(owner);proxy->listen(QHostAddress::LocalHost,0);
    QObject::connect(proxy,&QTcpServer::newConnection,owner,[proxy,attempts,background]{while(proxy->hasPendingConnections()){auto socket=proxy->nextPendingConnection();QObject::connect(socket,&QTcpSocket::readyRead,socket,[socket,attempts,background]{const auto first=socket->readAll().split('\n').value(0);if((first.contains("i18n.prismlauncher.org")||first.contains("prismlauncher.org/feed")||first.startsWith("CONNECT prismlauncher.org:443 ")))++*background;else ++*attempts;socket->write("HTTP/1.1 503 Audit forbids downloads\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");socket->disconnectFromHost();});QObject::connect(socket,&QTcpSocket::disconnected,socket,&QObject::deleteLater);}});
    APPLICATION->network()->setProxy(QNetworkProxy(QNetworkProxy::HttpProxy,"127.0.0.1",proxy->serverPort()));
    auto finish=[report,attempts,background,output](bool success,const QString& reason){(*report)["success"]=success;(*report)["error"]=reason;(*report)["networkAttempts"]=*attempts;(*report)["translationBackgroundAttempts"]=*background;QSaveFile file(output+"/launch-audit.json");if(file.open(QIODevice::WriteOnly)){file.write(QJsonDocument(*report).toJson());file.commit();}QTimer::singleShot(0,qApp,[success]{qApp->exit(success?0:1);});};
    const auto rootId=catalog->addRoot(root),version=qEnvironmentVariable("DEERAFT_AUDIT_VERSION","26.2_bac");
    auto instance=dynamic_cast<MinecraftInstance*>(bridge->resolveDirectoryReference("external:"+rootId+":"+version));
    if(!instance){finish(false,"Cannot resolve sample instance");return true;}
    (*report)["originalGameRoot"]=instance->gameRoot();
    instance->settings()->set("DeeraftGameDirectory",output+"/isolated-game");
    (*report)["librariesRoot"]=instance->librariesPath().absolutePath();(*report)["instanceRoot"]=instance->instanceRoot();(*report)["sample"]=version;(*report)["localMetadataReady"]=instance->property("deeraftLocalMetadataReady").toBool();
    (*report)["automaticJavaDownload"]=APPLICATION->settings()->get("AutomaticJavaDownload").toBool();
    (*report)["ignoreJavaCompatibility"]=APPLICATION->settings()->get("IgnoreJavaCompatibility").toBool();
    auto run=std::make_shared<std::function<void(int)>>();
    *run=[=](int pass){
        auto pipeline=new SequentialTask("Isolated resource audit");pipeline->setParent(owner);auto elapsed=std::make_shared<QElapsedTimer>();
        auto meta=makeShared<MinecraftLoadAndCheck>(instance,Net::Mode::Offline);pipeline->addTask(meta);
        QObject::connect(meta.get(),&Task::succeeded,owner,[instance]{instance->updateRuntimeContext();});
        auto reuse=makeShared<ResourceReuseTask>(instance);pipeline->addTask(reuse);pipeline->addTask(makeShared<LibrariesTask>(instance));pipeline->addTask(makeShared<AssetUpdateTask>(instance));
        QObject::connect(pipeline,&Task::failed,owner,[=](const QString& error){(*report)["failedPass"]=pass;finish(false,error);});
        QObject::connect(pipeline,&Task::succeeded,owner,[=]{(*report)[pass==1?"coldMs":"warmMs"]=double(elapsed->elapsed());(*report)["readOnlyAssets"]=instance->property("deeraftAssetsRoot").toString();(*report)["classPath"]=QJsonArray::fromStringList(instance->getClassPath());if(pass==1){pipeline->deleteLater();(*run)(2);}else finish(*attempts==0,*attempts?"Unexpected network requests":"");});
        elapsed->start();pipeline->start();
    };
    auto javas=APPLICATION->javalist();auto detection=javas->getLoadTask();
    auto detected=[=]{QJsonArray local;for(int i=0;i<javas->count();++i){auto java=std::dynamic_pointer_cast<JavaInstall>(javas->at(i));if(!java)continue;local.append(QJsonObject{{"version",java->id.toString()},{"path",java->path}});if(i==0){instance->settings()->set("OverrideJavaLocation",true);instance->settings()->set("JavaVersion",java->id.toString());instance->settings()->set("JavaArchitecture",java->is_64bit?"64":"32");instance->settings()->set("JavaRealArchitecture",java->arch);}}(*report)["localJavas"]=local;(*run)(1);};
    if(detection)QObject::connect(detection.get(),&Task::finished,owner,detected);else detected();
    QTimer::singleShot(120000,owner,[finish]{finish(false,"Audit timed out");});
    return true;
}
