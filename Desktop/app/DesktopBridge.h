#pragma once
#include <QObject>
#include <QVariant>
#include <QPointer>
#include <QSettings>
#include <QUrl>
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
    Q_INVOKABLE QString chooseDirectory();
    Q_INVOKABLE QUrl chooseFile(const QString& filter = {});
    Q_INVOKABLE void openPath(const QString& path);
    Q_INVOKABLE void addOfflineAccount(const QString& name);
    Q_INVOKABLE void selectAccount(const QString& uuid);
    Q_INVOKABLE void cancelTask(const QString& id);
    Q_INVOKABLE void openWebsite();
    Q_INVOKABLE void openLive(const QString& roomId);
    Q_INVOKABLE void launchExternal(const QString& rootId,const QString& versionId);
    void setExternalLauncher(Deeraft::NativeExternalLaunchController* launcher);
    static void trackTask(Task* task);
signals:
    void changed();
    void themeChanged();
    void tasksChanged();
private:
    void applyPalette();
    void updateTask(Task* task, const QString& state = {});
    MainWindow* m_window;
    QSettings m_settings;
    QVariantList m_tasks;
    QHash<QString,QPointer<Task>> m_taskObjects;
    QString m_error;
    static QPointer<DesktopBridge> s_instance;
};
