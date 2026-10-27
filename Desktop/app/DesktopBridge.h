#pragma once
#include <QObject>
#include <QVariant>
#include <QPointer>
#include <QSettings>
#include <QUrl>
#include <QSet>
class MainWindow;
class Task;
namespace Deeraft {class ExternalGameCatalog; class NativeExternalLaunchController;}
class DesktopBridge final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList instances READ instances NOTIFY changed)
    Q_PROPERTY(QVariantList accounts READ accounts NOTIFY changed)
    Q_PROPERTY(QVariantList tasks READ tasks NOTIFY tasksChanged)
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY themeChanged)
    Q_PROPERTY(bool dark READ dark NOTIFY themeChanged)
    Q_PROPERTY(QString error READ error NOTIFY changed)
public:
    explicit DesktopBridge(MainWindow* window);
    QVariantList instances() const;
    QVariantList accounts() const;
    QVariantList tasks() const { return m_tasks; }
    QString theme() const;
    void setTheme(const QString& value);
    bool dark() const;
    QString error() const { return m_error; }
    Q_INVOKABLE void action(const QString& name, const QString& instanceId = {});
    Q_INVOKABLE void advanced();
    Q_INVOKABLE void selectInstance(const QString& id);
    Q_INVOKABLE void launchInstance(const QString& id, const QString& address = {});
    Q_INVOKABLE QVariantList resources(const QString& id,const QString& kind) const;
    Q_INVOKABLE bool setModEnabled(const QString& id,const QString& fileName,bool enabled);
    Q_INVOKABLE QString readGameLog(const QString& id) const;
    Q_INVOKABLE QString chooseDirectory();
    Q_INVOKABLE QUrl chooseFile(const QString& filter = {});
    Q_INVOKABLE void openPath(const QString& path);
    Q_INVOKABLE void addOfflineAccount(const QString& name);
    Q_INVOKABLE void selectAccount(const QString& uuid);
    Q_INVOKABLE void cancelTask(const QString& id);
    Q_INVOKABLE void openWebsite();
    Q_INVOKABLE void openLive(const QString& roomId);
    Q_INVOKABLE void launchExternal(const QString& rootId,const QString& versionId,const QString& address = {},const QString& javaOverride = {});
    void setExternalLauncher(Deeraft::NativeExternalLaunchController* launcher);
    static void trackTask(Task* task);
signals:
    void changed();
    void themeChanged();
    void tasksChanged();
    void gameStarted(const QString& name,const QString& version);
private:
    void applyPalette();
    void observeInstances();
    QSet<QObject*> m_observed;
    void updateTask(Task* task, const QString& state = {});
    MainWindow* m_window;
    QSettings m_settings;
    QVariantList m_tasks;
    QHash<QString,QPointer<Task>> m_taskObjects;
    QString m_error;
    static QPointer<DesktopBridge> s_instance;
};
