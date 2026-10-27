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
public:
    explicit DesktopWindow(MainWindow* commands);
    void setContent(QQuickView* content);
    void setExternalLauncher(Deeraft::NativeExternalLaunchController* launcher);
    void activate(bool minimized = false);
protected:
    void closeEvent(QCloseEvent* event) override;
private:
    MainWindow* m_commands;
    QPointer<Deeraft::NativeExternalLaunchController> m_external;
};
