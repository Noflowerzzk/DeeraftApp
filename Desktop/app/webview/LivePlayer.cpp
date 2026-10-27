#include "LivePlayer.h"
#include <QDialog>
#include <QCoreApplication>
#include <QDir>
#include <QLabel>
#include <QRegularExpression>
#include <QResizeEvent>
#include <QTimer>
#include <QVBoxLayout>
#ifdef Q_OS_WIN
#define WEBVIEW_STATIC
#include "vendor/webview.h"
class PlayerHost final:public QWidget {
public:
    explicit PlayerHost(QWidget* parent):QWidget(parent){setAttribute(Qt::WA_NativeWindow);}
    ~PlayerHost()override{if(m_view)webview_destroy(m_view);}
    bool load(const QString& url){
        m_view=webview_create(0,reinterpret_cast<void*>(winId()));
        if(!m_view)return false;
        webview_navigate(m_view,url.toUtf8().constData());
        resizeBrowser();return true;
    }
protected:
    void resizeEvent(QResizeEvent* event)override{QWidget::resizeEvent(event);resizeBrowser();}
private:
    void resizeBrowser(){if(!m_view)return;auto controller=static_cast<ICoreWebView2Controller*>(webview_get_native_handle(m_view,WEBVIEW_NATIVE_HANDLE_KIND_BROWSER_CONTROLLER));if(controller){RECT rect;GetClientRect(reinterpret_cast<HWND>(winId()),&rect);controller->put_Bounds(rect);}}
    webview_t m_view=nullptr;
};
#endif
void showLivePlayer(QWidget* parent,const QString& roomId,const QString& data){
    if(!QRegularExpression("^[0-9]{1,20}$").match(roomId).hasMatch())return;
    auto dialog=new QDialog(parent);dialog->setAttribute(Qt::WA_DeleteOnClose);dialog->setWindowTitle("DeeraftApp · 直播");dialog->resize(960,640);
    auto layout=new QVBoxLayout(dialog);layout->setContentsMargins(0,0,0,0);
#ifdef Q_OS_WIN
    qputenv("WEBVIEW2_USER_DATA_FOLDER",QDir::toNativeSeparators(QDir(data).filePath("webview2")).toUtf8());
    const QString localRuntime=QDir(QCoreApplication::applicationDirPath()).filePath("WebView2Runtime");
    if(QDir(localRuntime).exists())qputenv("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER",QDir::toNativeSeparators(localRuntime).toUtf8());
    auto host=new PlayerHost(dialog);layout->addWidget(host);dialog->show();
    if(!host->load("https://www.bilibili.com/blackboard/live/live-activity-player.html?cid="+roomId+"&quality=0")){
        host->hide();auto label=new QLabel("无法加载 WebView2。请将 x64 Fixed Version Runtime 放入程序旁的 WebView2Runtime 文件夹。",dialog);label->setWordWrap(true);layout->addWidget(label);
    }
#else
    layout->addWidget(new QLabel("直播播放器需要 Windows WebView2",dialog));dialog->show();
#endif
}
