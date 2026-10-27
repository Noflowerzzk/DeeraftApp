#include "DesktopWindow.h"
#include "ui/MainWindow.h"
#include "compat/NativeExternalLaunchController.h"
#include "Application.h"
#include <QCloseEvent>
#include <QApplication>
#include <QWindow>

namespace {
class SecondaryWindowOwner final : public QObject {
public:
    SecondaryWindowOwner(MainWindow* commands, QWidget* host):QObject(host),m_commands(commands),m_host(host){qApp->installEventFilter(this);}
protected:
    bool eventFilter(QObject* object,QEvent* event) override {
        auto widget=qobject_cast<QWidget*>(object);
        if(event->type()==QEvent::Show&&widget&&widget->isWindow()&&widget!=m_host&&widget!=m_commands&&m_commands->isAncestorOf(widget)){
            if(auto handle=widget->windowHandle();handle&&m_host->windowHandle())handle->setTransientParent(m_host->windowHandle());
            widget->setWindowIcon(m_host->windowIcon());
        }
        return false;
    }
private:
    MainWindow* m_commands;QWidget* m_host;
};
}

#include <QQuickView>
#include <QSettings>
#include <QVBoxLayout>

DesktopWindow::DesktopWindow(MainWindow* commands)
    : QWidget(commands, Qt::Window), m_commands(commands) {
    setObjectName("DeeraftDesktopWindow");
    new SecondaryWindowOwner(commands,this);
    setWindowTitle("DeeraftApp");
    setWindowIcon(commands->windowIcon());
    resize(1440, 960);
    setMinimumSize(900, 640);
    auto layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);
    QSettings settings(APPLICATION->dataRoot()+"/desktop.ini", QSettings::IniFormat);
    restoreGeometry(settings.value("window/geometry").toByteArray());
}
void DesktopWindow::setContent(QQuickView* content) { auto container=QWidget::createWindowContainer(content,this);container->setFocusPolicy(Qt::StrongFocus);layout()->addWidget(container); }
void DesktopWindow::setExternalLauncher(Deeraft::NativeExternalLaunchController* launcher) { m_external=launcher; }
void DesktopWindow::activate(bool minimized) {
    if(minimized) { showMinimized(); return; }
    if(isMinimized()) showNormal(); else show();
    raise();
    activateWindow();
}
void DesktopWindow::closeEvent(QCloseEvent* event) {
    if(m_external && m_external->running()) { event->ignore(); showMinimized(); return; }
    QSettings settings(APPLICATION->dataRoot()+"/desktop.ini", QSettings::IniFormat);
    settings.setValue("window/geometry", saveGeometry());
    // Retain Prism's running-game and tray lifecycle, without displaying it.
    if(m_commands->close()) event->accept(); else event->ignore();
}
