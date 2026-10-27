// SPDX-License-Identifier: GPL-3.0-only
#include "ExternalAuthStep.h"
#include "accounts/ExternalAuthService.h"
#include <QNetworkReply>
#include <QJsonArray>
#include <QJsonDocument>
#include <QImage>

void ExternalAuthStep::perform()
{
    DeeraftAuth::refresh(&m_network, m_data->externalSession, [this](QJsonObject session, QString error) {
        if (m_cancelled) return;
        if (!error.isEmpty()) {
            emit finished(AccountTaskState::STATE_FAILED_SOFT, error);
            return;
        }
        const auto profile = session.value("selectedProfile").toObject();
        m_data->externalSession = session;
        m_data->yggdrasilToken.token = session.value("accessToken").toString(session.value("access_token").toString());
        m_data->yggdrasilToken.issueInstant = QDateTime::currentDateTimeUtc();
        m_data->yggdrasilToken.notAfter = m_data->yggdrasilToken.issueInstant.addSecs(session.value("expires_in").toInt(86400));
        m_data->yggdrasilToken.validity = Validity::Certain;
        m_data->minecraftProfile.id = profile.value("id").toString().remove('-');
        m_data->minecraftProfile.name = profile.value("name").toString();
        m_data->minecraftProfile.validity = Validity::Certain;
        loadSkin();
    });
}
void ExternalAuthStep::loadSkin()
{
    const auto done=[this]{if(!m_cancelled)emit finished(AccountTaskState::STATE_WORKING,tr("第三方账号已刷新"));};
    const auto server=DeeraftAuth::apiRoot(m_data->externalSession.value("server").toString());
    if(!DeeraftAuth::secureUrl(server)){done();return;}
    QNetworkRequest request(QUrl(server.toString()+"/sessionserver/session/minecraft/profile/"+m_data->minecraftProfile.id));
    request.setTransferTimeout(5000);request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,QNetworkRequest::SameOriginRedirectPolicy);
    auto reply=m_network.get(request);
    connect(reply,&QNetworkReply::finished,this,[this,reply,done]{
        const auto bytes=reply->readAll();reply->deleteLater();if(m_cancelled)return;
        const auto profile=QJsonDocument::fromJson(bytes).object();QUrl skin;
        for(const auto& value:profile.value("properties").toArray()){
            const auto p=value.toObject();if(p.value("name").toString()!="textures")continue;
            const auto textures=QJsonDocument::fromJson(QByteArray::fromBase64(p.value("value").toString().toUtf8())).object();
            skin=QUrl(textures.value("textures").toObject().value("SKIN").toObject().value("url").toString());
        }
        if(!DeeraftAuth::secureUrl(skin)){done();return;}
        QNetworkRequest image(skin);image.setTransferTimeout(5000);image.setAttribute(QNetworkRequest::RedirectPolicyAttribute,QNetworkRequest::NoLessSafeRedirectPolicy);
        auto download=m_network.get(image);
        connect(download,&QNetworkReply::downloadProgress,download,[download](qint64 received,qint64){if(received>5*1024*1024)download->abort();});
        connect(download,&QNetworkReply::finished,this,[this,download,skin,done]{
            const auto data=download->readAll();download->deleteLater();if(m_cancelled)return;
            QImage decoded;if(data.size()<=5*1024*1024 && decoded.loadFromData(data,"PNG") && decoded.width()==64 && (decoded.height()==32||decoded.height()==64)){
                m_data->minecraftProfile.skin.data=data;m_data->minecraftProfile.skin.url=skin.toString();
            }
            done();
        });
    });
}
void ExternalAuthStep::abort()
{
    m_cancelled = true;
    for (auto* reply : m_network.findChildren<QNetworkReply*>()) reply->abort();
}
