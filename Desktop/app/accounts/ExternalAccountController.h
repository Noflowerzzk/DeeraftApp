// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <QObject>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QTimer>
#include <QVariantList>
#include <functional>

class ExternalAccountController : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QVariantList profiles READ profiles NOTIFY changed)
    Q_PROPERTY(QString deviceCode READ deviceCode NOTIFY changed)
    Q_PROPERTY(QString verificationUri READ verificationUri NOTIFY changed)
public:
    explicit ExternalAccountController(const QString& dataDirectory, QObject* parent = nullptr);
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QVariantList profiles() const { return m_profiles; }
    QString deviceCode() const { return m_device.value("user_code").toString(); }
    QString verificationUri() const { return m_device.value("verification_uri_complete").toString(m_device.value("verification_uri").toString()); }
    Q_INVOKABLE void loginAuthlib(const QString& server, const QString& username, const QString& password);
    Q_INVOKABLE void startConnect(const QString& discoveryAddress, const QString& clientId, const QString& yggdrasilServer);
    Q_INVOKABLE void selectProfile(const QString& id);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void openVerificationPage();
signals:
    void changed();
    void accountAdded();
private:
    void begin();
    void fail(const QString& error);
    void choose(const QJsonObject& selected, const QJsonArray& available);
    void finish(const QJsonObject& profile);
    void prepareInjector(std::function<void(QString)> done);
    void pollDevice();
    QString m_dataDirectory, m_error;
    bool m_busy = false;
    int m_generation = 0;
    QNetworkAccessManager m_network;
    QJsonObject m_session, m_metadata, m_device;
    QVariantList m_profiles;
    QTimer m_poll;
    qint64 m_expiresAt = 0;
};
