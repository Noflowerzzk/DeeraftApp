#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QSettings>
#include <QJsonObject>
#include <QSaveFile>
#include <memory>
class QNetworkReply;
class AppUpdater final:public QObject {
 Q_OBJECT
 Q_PROPERTY(QString version READ version CONSTANT)
 Q_PROPERTY(QString latest READ latest NOTIFY changed)
 Q_PROPERTY(QString status READ status NOTIFY changed)
 Q_PROPERTY(bool busy READ busy NOTIFY changed)
 Q_PROPERTY(bool available READ available NOTIFY changed)
 Q_PROPERTY(bool ready READ ready NOTIFY changed)
 Q_PROPERTY(bool automatic READ automatic WRITE setAutomatic NOTIFY changed)
 Q_PROPERTY(double progress READ progress NOTIFY changed)
public:
 explicit AppUpdater(const QString& data,QObject* parent=nullptr);
 QString version()const{return QStringLiteral("0.6.0");}
 QString latest()const{return m_release["version"].toString();}
 QString status()const{return m_status;}
 bool busy()const{return !m_reply.isNull();}
 bool available()const;
 bool ready()const{return !m_installer.isEmpty();}
 bool automatic()const{return m_settings.value("updates/automatic",true).toBool();}
 void setAutomatic(bool enabled);
 double progress()const{return m_progress;}
 static QJsonObject verifyManifest(const QByteArray& envelope,const QByteArray& publicKey,const QString& expectedHost={});
 Q_INVOKABLE void check();
 Q_INVOKABLE void download();
 Q_INVOKABLE void cancel();
 Q_INVOKABLE void install(bool gamesRunning);
signals:
 void changed();
 void notice(const QString& message);
private:
 friend class DesktopTasksTest;
 void fail(const QString& message);
 QString m_data,m_status,m_installer;
 QNetworkAccessManager m_network;
 QPointer<QNetworkReply> m_reply;
 QSettings m_settings;
 QJsonObject m_release;
 double m_progress=0;
 std::unique_ptr<QSaveFile> m_output;
 QUrl m_channelUrl=QUrl("http://mc.ainfinitythecoder.cn/downloads/windows/latest.json");
 QByteArray m_testPublicKey;
};
