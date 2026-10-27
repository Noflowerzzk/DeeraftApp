// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include "AuthStep.h"
#include <QNetworkAccessManager>
class ExternalAuthStep : public AuthStep {
    Q_OBJECT
public:
    explicit ExternalAuthStep(AccountData* data) : AuthStep(data) {}
    QString describe() override { return tr("刷新第三方账号"); }
    void perform() override;
    void abort() override;
private:
    void loadSkin();
    QNetworkAccessManager m_network;
    bool m_cancelled = false;
};
