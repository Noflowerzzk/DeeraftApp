#pragma once
#include <QObject>
#include <QVariant>
#include <QJsonObject>
#include <QPointer>
namespace Deeraft { class ExternalGameCatalog; }
class DesktopLibrary final : public QObject {
 Q_OBJECT
 Q_PROPERTY(QVariantList externalInstances READ externalInstances NOTIFY changed)
 Q_PROPERTY(QVariantList servers READ servers NOTIFY changed)
 Q_PROPERTY(QVariantMap links READ links NOTIFY changed)
 Q_PROPERTY(QVariantMap addresses READ addresses NOTIFY changed)
 Q_PROPERTY(QVariantMap metadata READ metadata NOTIFY changed)
 Q_PROPERTY(QString error READ error NOTIFY changed)
 Q_PROPERTY(bool reducedMotion READ reducedMotion WRITE setReducedMotion NOTIFY changed)
public:
 DesktopLibrary(const QString& directory,Deeraft::ExternalGameCatalog* catalog,QObject* parent=nullptr);
 QVariantList externalInstances() const {return m_instances;}
 QVariantList servers() const;
 QVariantMap links() const {return m_data.value("links").toObject().toVariantMap();}
 QVariantMap addresses() const {return m_data.value("addresses").toObject().toVariantMap();}
 QVariantMap metadata() const {return m_data.value("metadata").toObject().toVariantMap();}
 QString error() const{return m_error;}
 bool reducedMotion() const{return m_data.value("reducedMotion").toBool();}
 void setReducedMotion(bool reduced);
 Q_INVOKABLE void refreshCatalog();
 Q_INVOKABLE bool setMetadata(const QString& key,const QVariantMap& value);
 Q_INVOKABLE bool associate(const QString& server,const QString& instance,const QString& address = {});
 Q_INVOKABLE QString saveServer(const QString& id,const QString& name,const QString& address,const QString& instance);
 Q_INVOKABLE bool removeServer(const QString& id);
 Q_INVOKABLE void refreshStatus(const QString& id);
 Q_INVOKABLE void refreshAllStatuses();
signals:
 void changed();
private:
 bool commit(QJsonObject next);
 void finishStatus(const QString& id,const QString& epoch,const QVariantMap& status);
 QString m_file,m_error;
 QJsonObject m_data;
 Deeraft::ExternalGameCatalog* m_catalog;
 QVariantList m_instances;
 QMap<QString,QVariantMap> m_status;
 QMap<QString,QString> m_requests;
};
