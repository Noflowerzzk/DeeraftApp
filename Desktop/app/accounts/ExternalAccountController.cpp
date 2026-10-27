// SPDX-License-Identifier: GPL-3.0-only
#include "ExternalAccountController.h"
#include "ExternalAuthService.h"
#include "Application.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/MinecraftAccount.h"
#include <QCryptographicHash>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QNetworkReply>
#include <QSaveFile>
#include <QUuid>

ExternalAccountController::ExternalAccountController(const QString& dir,QObject* parent)
    :QObject(parent),m_dataDirectory(dir),m_network(this){
    m_poll.setSingleShot(true);
    connect(&m_poll,&QTimer::timeout,this,&ExternalAccountController::pollDevice);
}
void ExternalAccountController::begin(){cancel();m_busy=true;m_error.clear();m_profiles.clear();m_session={};m_device={};emit changed();}
void ExternalAccountController::fail(const QString& error){m_poll.stop();m_busy=false;m_error=error;emit changed();}
void ExternalAccountController::cancel(){++m_generation;m_poll.stop();m_busy=false;for(auto reply:m_network.findChildren<QNetworkReply*>())reply->abort();emit changed();}
void ExternalAccountController::loginAuthlib(const QString& server,const QString& username,const QString& password){
    begin();const int epoch=m_generation;auto root=DeeraftAuth::apiRoot(server);
    if(!DeeraftAuth::secureUrl(root)){fail(tr("请输入 HTTPS 认证地址"));return;}
    const QString client=QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_session={{"provider","authlib"},{"server",root.toString()},{"clientToken",client}};
    DeeraftAuth::request(&m_network,QUrl(root.toString()+"/authserver/authenticate"),
        {{"agent",QJsonObject{{"name","Minecraft"},{"version",1}}},{"username",username},{"password",password},{"clientToken",client},{"requestUser",true}},
        [this,epoch](QJsonObject value,QString error){if(epoch!=m_generation)return;if(!error.isEmpty()){fail(error);return;}
            for(auto it=value.begin();it!=value.end();++it)m_session[it.key()]=it.value();
            choose(value.value("selectedProfile").toObject(),value.value("availableProfiles").toArray());});
}
void ExternalAccountController::choose(const QJsonObject& selected,const QJsonArray& available){
    if(!selected.isEmpty()){finish(selected);return;}
    if(available.size()==1){finish(available.first().toObject());return;}
    if(available.isEmpty()){fail(tr("该账号没有可用角色"));return;}
    m_profiles=available.toVariantList();m_busy=false;emit changed();
}
void ExternalAccountController::selectProfile(const QString& id){
    for(const auto& value:m_profiles){auto role=QJsonObject::fromVariantMap(value.toMap());if(role.value("id").toString()!=id)continue;
        m_busy=true;emit changed();
        if(m_session.value("provider").toString()=="authlib"){
            const int epoch=m_generation;
            DeeraftAuth::request(&m_network,QUrl(DeeraftAuth::apiRoot(m_session.value("server").toString()).toString()+"/authserver/refresh"),
               {{"accessToken",m_session.value("accessToken")},{"clientToken",m_session.value("clientToken")},{"selectedProfile",role},{"requestUser",true}},
               [this,epoch,role](QJsonObject value,QString error){if(epoch!=m_generation)return;if(!error.isEmpty()){fail(error);return;}
                   for(auto it=value.begin();it!=value.end();++it) m_session[it.key()]=it.value();
                   finish(value.value("selectedProfile").toObject(role));});
        }else{finish(role);}
        return;
    }
    fail(tr("角色不存在"));
}
void ExternalAccountController::finish(const QJsonObject& role){
    m_session["selectedProfile"]=role;const int epoch=m_generation;
    prepareInjector([this,epoch](QString path){if(epoch!=m_generation || path.isEmpty())return;
        m_session["injectorPath"]=path;
        QFile file(path);if(!file.open(QIODevice::ReadOnly)){fail(tr("无法读取认证组件"));return;}
        m_session["injectorSha256"]=QString::fromLatin1(QCryptographicHash::hash(file.readAll(),QCryptographicHash::Sha256).toHex());
        auto account=MinecraftAccount::createExternal(m_session);
        if(!account){fail(tr("站点返回的账号信息不完整"));return;}
        auto list=APPLICATION->accounts();
        const int existing=list->findAccountByProfileId(account->profileId());
        if(existing>=0){fail(tr("该角色已存在，请先在账号管理中移除旧账号"));return;}
        list->addAccount(account);list->setDefaultAccount(account);m_busy=false;m_profiles.clear();m_session={};emit changed();emit accountAdded();
    });
}
void ExternalAccountController::prepareInjector(std::function<void(QString)> done){
    const int epoch=m_generation;
    DeeraftAuth::request(&m_network,QUrl("https://authlib-injector.yushi.moe/artifact/latest.json"),{},
       [this,epoch,done](QJsonObject meta,QString error){if(epoch!=m_generation)return;if(!error.isEmpty()){fail(error);return;}
        const QString hash=meta.value("checksums").toObject().value("sha256").toString().toLower();
        const QUrl url(meta.value("download_url").toString());
        if(hash.size()!=64 || !DeeraftAuth::secureUrl(url)){fail(tr("认证组件下载元数据无效"));return;}
        const QString path=QDir(m_dataDirectory).filePath("authlib-injector-"+hash+".jar");
        QDir().mkpath(m_dataDirectory);
        QFile old(path);if(old.open(QIODevice::ReadOnly) && QCryptographicHash::hash(old.readAll(),QCryptographicHash::Sha256).toHex()==hash.toLatin1()){done(path);return;}
        QNetworkRequest request(url);request.setTransferTimeout(60000);request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,QNetworkRequest::NoLessSafeRedirectPolicy);
        auto reply=m_network.get(request);
        connect(reply,&QNetworkReply::finished,this,[this,epoch,reply,path,hash,done]{auto bytes=reply->readAll();auto error=reply->error();reply->deleteLater();if(epoch!=m_generation)return;
            if(error!=QNetworkReply::NoError){fail(tr("认证组件下载失败"));return;}
            if(QCryptographicHash::hash(bytes,QCryptographicHash::Sha256).toHex()!=hash.toLatin1()){fail(tr("认证组件校验失败"));return;}
            QSaveFile file(path);if(!file.open(QIODevice::WriteOnly)||file.write(bytes)!=bytes.size()||!file.commit()){fail(tr("认证组件保存失败"));return;}done(path);
        });
    });
}
void ExternalAccountController::startConnect(const QString& address,const QString& clientId,const QString& server){
    begin();const int epoch=m_generation;
    QUrl discovery(address.trimmed());
    if(discovery.path().isEmpty()||discovery.path()=="/")discovery.setPath("/.well-known/openid-configuration");
    if(clientId.trimmed().isEmpty()||!DeeraftAuth::secureUrl(DeeraftAuth::apiRoot(server))){fail(tr("请填写 Client ID 和 HTTPS Yggdrasil 地址"));return;}
    m_session={{"provider","connect"},{"clientId",clientId.trimmed()},{"server",DeeraftAuth::apiRoot(server).toString()},{"discovery",discovery.toString()}};
    DeeraftAuth::discover(&m_network,discovery,[this,epoch,clientId](QJsonObject meta,QString error){if(epoch!=m_generation)return;if(!error.isEmpty()){fail(error);return;}
        m_metadata=meta;m_session["metadata"]=meta;
        DeeraftAuth::request(&m_network,QUrl(meta.value("device_authorization_endpoint").toString()),
            {{"client_id",clientId.trimmed()},{"scope","openid offline_access Yggdrasil.PlayerProfiles.Select Yggdrasil.Server.Join"}},
            [this,epoch](QJsonObject device,QString error){if(epoch!=m_generation)return;if(!error.isEmpty()){fail(error);return;}
                if(device.value("device_code").toString().isEmpty()){fail(tr("站点未返回设备授权码"));return;}
                m_device=device;m_expiresAt=QDateTime::currentSecsSinceEpoch()+device.value("expires_in").toInt(600);emit changed();
                openVerificationPage();m_poll.start(qMax(1,device.value("interval").toInt(5))*1000);
            },true);
    });
}
void ExternalAccountController::openVerificationPage(){auto url=QUrl(verificationUri());if(DeeraftAuth::secureUrl(url))QDesktopServices::openUrl(url);}
void ExternalAccountController::pollDevice(){
    if(QDateTime::currentSecsSinceEpoch()>=m_expiresAt){fail(tr("设备授权码已过期"));return;}
    const int epoch=m_generation;
    DeeraftAuth::request(&m_network,QUrl(m_metadata.value("token_endpoint").toString()),
        {{"grant_type","urn:ietf:params:oauth:grant-type:device_code"},{"device_code",m_device.value("device_code")},{"client_id",m_session.value("clientId")}},
        [this,epoch](QJsonObject tokens,QString error){if(epoch!=m_generation)return;
            auto code=tokens.value("error").toString();
            if(code=="authorization_pending"||code=="slow_down"){
                int interval=qMax(1,m_device.value("interval").toInt(5));if(code=="slow_down"){interval+=5;m_device["interval"]=interval;}m_poll.start(interval*1000);return;}
            if(!error.isEmpty()){fail(error);return;}
            DeeraftAuth::verifyConnect(&m_network,m_metadata,m_session.value("clientId").toString(),tokens,
                [this,epoch,tokens](QJsonObject roles,QString error){if(epoch!=m_generation)return;if(!error.isEmpty()){fail(error);return;}
                    for(auto it=tokens.begin();it!=tokens.end();++it)m_session[it.key()]=it.value();
                    choose(roles.value("selectedProfile").toObject(),roles.value("availableProfiles").toArray());});
        },true);
}
