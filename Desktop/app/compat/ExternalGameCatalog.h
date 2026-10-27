#pragma once

#include <QJsonObject>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <memory>
#include <map>

class QLockFile;

namespace Deeraft {

// Reads existing launcher layouts. It never migrates or rewrites their settings.
class ExternalVersionResolver
{
public:
    static QString normalizeRoot(const QString &path);
    static QString rootId(const QString &path);
    static QVariantMap resolve(const QString &root, const QString &versionId,
                               const QVariantMap &rootOptions = {});
    static QVariantList scan(const QString &root, const QVariantMap &rootOptions = {});
};

class ExternalGameCatalog final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList roots READ roots NOTIFY rootsChanged)
    Q_PROPERTY(QVariantList versions READ versions NOTIFY versionsChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    explicit ExternalGameCatalog(const QString &dataDirectory, QObject *parent = nullptr);
    ~ExternalGameCatalog() override;
    QVariantList roots() const { return m_roots; }
    QVariantList versions() const { return m_versions; }
    QString error() const { return m_error; }

    Q_INVOKABLE QString addRoot(const QString &path);
    Q_INVOKABLE bool removeRoot(const QString &id);
    // Optional global launcher defaults, entered explicitly. Account files are never read.
    Q_INVOKABLE bool setRootOptions(const QString &id, const QVariantMap &options);
    Q_INVOKABLE QVariantList scanRoot(const QString &id);
    Q_INVOKABLE QVariantMap resolveVersion(const QString &rootId, const QString &versionId);
    // Return a non-empty lock key on success. Keep it until the game process exits.
    Q_INVOKABLE QString acquireLaunchLock(const QString &rootId, const QString &versionId);
    Q_INVOKABLE void releaseLaunchLock(const QString &key);

signals:
    void rootsChanged();
    void versionsChanged();
    void errorChanged();

private:
    QVariantMap findRoot(const QString &id) const;
    bool save(const QVariantList &roots);
    void setError(const QString &error);
    QString m_dataDirectory;
    QString m_catalogFile;
    QVariantList m_roots;
    QVariantList m_versions;
    QString m_error;
    std::map<QString, std::unique_ptr<QLockFile>> m_locks;
};

} // namespace Deeraft
