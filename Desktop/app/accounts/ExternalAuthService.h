// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QPointer>
#include <functional>

namespace DeeraftAuth {
using JsonCallback = std::function<void(QJsonObject, QString)>;
QByteArray protect(const QByteArray& plain);
QByteArray unprotect(const QByteArray& cipher);
bool secureUrl(const QUrl& url);
QUrl apiRoot(QString input);
void request(QNetworkAccessManager* network, const QUrl& url, const QJsonObject& body, JsonCallback done,
             bool form = false, const QString& bearer = {});
void discover(QNetworkAccessManager* network, const QUrl& url, JsonCallback done);
void verifyConnect(QNetworkAccessManager* network, const QJsonObject& metadata, const QString& clientId,
                   const QJsonObject& tokens, JsonCallback done);
void refresh(QNetworkAccessManager* network, const QJsonObject& account, JsonCallback done);
}
