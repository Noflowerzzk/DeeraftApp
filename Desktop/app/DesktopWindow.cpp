#include "DesktopWindow.h"
#include "ui/MainWindow.h"
#include "compat/NativeExternalLaunchController.h"
#include "Application.h"
#include <QCloseEvent>
#include <QApplication>
#include <QWindow>
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#ifdef Q_OS_WIN
#include <windows.h>
#include <shobjidl.h>
#include <propkey.h>
#include <propvarutil.h>
#endif

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
#include <QQuickItem>
#include <QTimer>
#include <QSettings>
#include <QVBoxLayout>
namespace {
class ViewportSizer final : public QObject {
public:
    ViewportSizer(QWidget* container,QQuickView* view):QObject(container),m_container(container),m_view(view){container->installEventFilter(this);}
    void sync(){
        const auto size=m_container->size();if(size.isEmpty())return;
        m_view->setGeometry(QRect(QPoint(),size));
        m_view->contentItem()->setSize(QSizeF(size));
        if(auto root=m_view->rootObject())root->setSize(QSizeF(size));
    }
protected:
    bool eventFilter(QObject*,QEvent* event)override{if(event->type()==QEvent::Resize || event->type()==QEvent::Show)QTimer::singleShot(0,this,[this]{sync();});return false;}
private:
    QWidget* m_container;QQuickView* m_view;
};
}

DesktopWindow::DesktopWindow(MainWindow* commands)
    : QWidget(nullptr, Qt::Window), m_commands(commands) {
#ifdef Q_OS_WIN
    SetCurrentProcessExplicitAppUserModelID(L"cn.ainfinity.DeeraftApp");
#endif
    connect(commands,&QObject::destroyed,this,&QObject::deleteLater);
    setObjectName("DeeraftDesktopWindow");
    new SecondaryWindowOwner(commands,this);
    setWindowTitle("DeeraftApp");
    QIcon icon(":/deeraft/assets/deeraft.ico");
    qApp->setWindowIcon(icon);commands->setWindowIcon(icon);
    setWindowIcon(icon);
    resize(1440, 960);
    setMinimumSize(900, 640);
    auto layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);
    QSettings settings(APPLICATION->dataRoot()+"/desktop.ini", QSettings::IniFormat);
    restoreGeometry(settings.value("window/geometry").toByteArray());
#ifdef Q_OS_WIN
    IPropertyStore* store=nullptr;
    if(SUCCEEDED(SHGetPropertyStoreForWindow(reinterpret_cast<HWND>(winId()),IID_PPV_ARGS(&store)))){
        auto set=[store](const PROPERTYKEY& key,const QString& text){PROPVARIANT value;PropVariantInit(&value);if(SUCCEEDED(InitPropVariantFromString(reinterpret_cast<LPCWSTR>(text.utf16()),&value)))store->SetValue(key,value);PropVariantClear(&value);};
        const auto iconPath=QCoreApplication::applicationDirPath()+"/DeeraftApp.ico";
        auto quote=[](QString path){path=QDir::toNativeSeparators(path);if(path.endsWith('\\'))path+='\\';return '"'+path+'"';};
        set(PKEY_AppUserModel_ID,"cn.ainfinity.DeeraftApp");
        set(PKEY_AppUserModel_RelaunchCommand,quote(QCoreApplication::applicationFilePath())+" --dir "+quote(QDir::cleanPath(APPLICATION->dataRoot())));
        set(PKEY_AppUserModel_RelaunchDisplayNameResource,"DeeraftApp");
        set(PKEY_AppUserModel_RelaunchIconResource,QDir::toNativeSeparators(QFileInfo::exists(iconPath)?iconPath:QCoreApplication::applicationFilePath())+",0");
        store->Commit();store->Release();
    }
#endif
}
void DesktopWindow::setContent(QQuickView* content) { auto container=QWidget::createWindowContainer(content,this);container->setFocusPolicy(Qt::StrongFocus);layout()->addWidget(container);layout()->activate();auto sizing=new ViewportSizer(container,content);sizing->sync();QTimer::singleShot(0,sizing,[sizing]{sizing->sync();}); }
void DesktopWindow::setExternalLauncher(Deeraft::NativeExternalLaunchController* launcher) { m_external=launcher; }
void DesktopWindow::activate(bool minimized) {
    if(minimized) { showMinimized(); return; }
    if(isMinimized()) showNormal(); else show();
    raise();
    activateWindow();
}
void DesktopWindow::closeEvent(QCloseEvent* event) {
    if(!m_confirmedClose && (m_activeJobs>0 || !APPLICATION->updatesAreAllowed() || (m_external&&m_external->running()))){event->ignore();emit closeConfirmationRequested();return;}
    m_confirmedClose=false;
    QSettings settings(APPLICATION->dataRoot()+"/desktop.ini", QSettings::IniFormat);
    settings.setValue("window/geometry", saveGeometry());
    // Games retain Prism's background lifecycle; closing the shell must not kill them.
    if(!APPLICATION->updatesAreAllowed() || (m_external&&m_external->running())) {event->ignore();hide();return;}
    // Retain Prism's running-game and tray lifecycle, without displaying it.
    if(m_commands->close()) event->accept(); else event->ignore();
}
void DesktopWindow::confirmClose(){m_confirmedClose=true;close();}
void DesktopWindow::changeEvent(QEvent* event){QWidget::changeEvent(event);if(event->type()==QEvent::WindowStateChange||event->type()==QEvent::ActivationChange)emit chromeChanged();}
