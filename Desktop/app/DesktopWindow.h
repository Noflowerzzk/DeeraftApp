#pragma once
#include <QWidget>
#include <QPointer>
class MainWindow;
class QQuickView;
namespace Deeraft { class NativeExternalLaunchController; }

// The app owns its own top-level window. Prism is an invisible command adapter;
// its menu/toolbar/layout restoration cannot alter this window's widget tree.
class DesktopWindow final : public QWidget {
    Q_OBJECT
    Q_PROPERTY(bool maximized READ isMaximized NOTIFY chromeChanged)
    Q_PROPERTY(int activeJobs MEMBER m_activeJobs)
public:
    explicit DesktopWindow(MainWindow* commands);
    void setContent(QQuickView* content);
    void setExternalLauncher(Deeraft::NativeExternalLaunchController* launcher);
    void activate(bool minimized = false);
    Q_INVOKABLE void toggleMaximize(){isMaximized()?showNormal():showMaximized();}
    Q_INVOKABLE void requestClose(){close();}
    Q_INVOKABLE void confirmClose();
signals:
    void closeConfirmationRequested();
    void chromeChanged();
protected:
    void closeEvent(QCloseEvent* event) override;
    void changeEvent(QEvent* event) override;
private:
    int m_activeJobs=0;
    bool m_confirmedClose=false;
    MainWindow* m_commands;
    QPointer<Deeraft::NativeExternalLaunchController> m_external;
};
