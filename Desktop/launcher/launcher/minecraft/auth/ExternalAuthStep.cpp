// SPDX-License-Identifier: GPL-3.0-only
#include "ExternalAuthStep.h"
#include "accounts/ExternalAuthService.h"
#include <QNetworkReply>

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
        emit finished(AccountTaskState::STATE_WORKING, tr("第三方账号已刷新"));
    });
}
void ExternalAuthStep::abort()
{
    m_cancelled = true;
    for (auto* reply : m_network.findChildren<QNetworkReply*>()) reply->abort();
}
