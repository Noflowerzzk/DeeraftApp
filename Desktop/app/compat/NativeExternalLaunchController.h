#pragma once

#include "ExternalGameCatalog.h"

#include <QProcess>
#include <functional>

namespace Deeraft {

// An auth session is supplied only after Prism/the selected account provider has
// refreshed it. The session and command line are never written to disk.
class NativeExternalLaunchController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString versionId READ versionId NOTIFY runningChanged)

public:
    using NativeExtractor = std::function<bool(const QStringList &, const QString &, QString &)>;
    explicit NativeExternalLaunchController(ExternalGameCatalog *catalog, const QString &dataDirectory, QObject *parent = nullptr);
    ~NativeExternalLaunchController() override;
    bool running() const { return m_process.state() != QProcess::NotRunning || !m_lockKey.isEmpty(); }
    QString error() const { return m_error; }
    QString versionId() const { return m_versionId; }
    void setNativeExtractor(NativeExtractor extractor) { m_extractor = std::move(extractor); }

    // Native-only: don't expose the returned arguments through QML, since they
    // contain the access token. Useful for launch integration and unit tests.
    static QVariantMap buildPlan(const QVariantMap &resolvedVersion, const QVariantMap &session,
                                 const QVariantMap &javaOptions, const QString &nativesDirectory);
    bool launch(const QString &rootId, const QString &versionId, const QVariantMap &session, const QVariantMap &javaOptions);
    Q_INVOKABLE void stop();

signals:
    void runningChanged();
    void errorChanged();
    void logLine(const QString &line);
    void started();
    void finished(int exitCode, bool crashed);

private:
    void setError(const QString &error);
    void releaseLock();
    QString redact(QString line) const;
    ExternalGameCatalog *m_catalog;
    QString m_dataDirectory;
    QString m_error;
    QString m_versionId;
    QString m_lockKey;
    QStringList m_secrets;
    QProcess m_process;
    NativeExtractor m_extractor;
};

} // namespace Deeraft
