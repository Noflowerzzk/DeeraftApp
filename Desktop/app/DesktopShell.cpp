#include "DesktopShell.h"
#include "DesktopBridge.h"
#include "community/CommunityClient.h"
#include "compat/ExternalGameCatalog.h"
#include "compat/NativeExternalLaunchController.h"
#include "accounts/ExternalAccountController.h"
#include "download/DownloadSources.h"
#include "archive/ArchiveReader.h"
#include "Application.h"
#include "ui/MainWindow.h"
#include "icons/IconList.h"
#include <QApplication>
#include <QFontDatabase>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickImageProvider>
#include <QQuickWidget>
#include <QQuickItem>
#include <QQuickStyle>
#include <QTimer>
#include <QFile>
#include <QSaveFile>
#include <QDir>
#include <QDesktopServices>
#include <QCoreApplication>

class InstanceIcons final : public QQuickImageProvider {
public:
    InstanceIcons():QQuickImageProvider(QQuickImageProvider::Pixmap){}
    QPixmap requestPixmap(const QString& id,QSize* size,const QSize& requested) override {
        QSize target=requested.isValid()?requested:QSize(64,64);
        if(size)*size=target;
        return APPLICATION->icons()->getIcon(id).pixmap(target);
    }
};
void installDeeraftShell(MainWindow* window){
    Q_INIT_RESOURCE(deeraft);
    qputenv("QT_SHADER_CACHE_PATH",QFile::encodeName(APPLICATION->dataRoot()+"/cache/shaders"));
    QQuickStyle::setStyle("Material");
    QFontDatabase::addApplicationFont(":/deeraft/fonts/NotoSansSC.ttf");
    qApp->setFont(QFont("Noto Sans SC",10));
    auto bridge=new DesktopBridge(window);
    auto community=new CommunityClient(APPLICATION->dataRoot()+"/community",window);
    community->setObjectName("deeraftCommunity");
    QObject::connect(community,&CommunityClient::microsoftAuthorizationStarted,window,[community](const QUrl&){
#ifdef Q_OS_WIN
        QSettings protocol("HKEY_CURRENT_USER\\Software\\Classes\\deeraft",QSettings::NativeFormat);
        protocol.setValue(".","URL:DeeraftApp community login");
        protocol.setValue("URL Protocol","");
        protocol.setValue("shell/open/command/.",QString("\"%1\" --dir \"%2\" \"%3\"").arg(QDir::toNativeSeparators(QCoreApplication::applicationFilePath()),QDir::toNativeSeparators(APPLICATION->dataRoot()),"%1"));
        protocol.sync();
#endif
        QDesktopServices::setUrlHandler("deeraft",community,"completeMicrosoftLogin");
    });
    auto external=new Deeraft::ExternalGameCatalog(APPLICATION->dataRoot()+"/external",window);
    auto launcher=new Deeraft::NativeExternalLaunchController(external,APPLICATION->dataRoot(),window);
    launcher->setNativeExtractor([](const QStringList& jars,const QString& destination,QString& error){
        for(const auto& jar:jars){
            MMCZip::ArchiveReader archive(jar);
            if(!archive.parse([&](MMCZip::ArchiveReader::File* file){
                if(!file->isFile())return true;
                QString name=file->filename();name.replace('\\','/');
                if(name.startsWith("META-INF/"))return true;
                name=QDir::cleanPath(name);
                if(name.startsWith('/')||name==".."||name.startsWith("../")||name.contains(':')){error="原生库包含非法路径";return false;}
                const QString target=QDir(destination).filePath(name);
                if(!QDir().mkpath(QFileInfo(target).absolutePath())){error="无法创建原生库目录";return false;}
                int status=0;auto bytes=file->readAll(&status);QSaveFile out(target);
                if(status<0||!out.open(QIODevice::WriteOnly)||out.write(bytes)!=bytes.size()||!out.commit()){error="无法解压原生库";return false;}
                return true;
            })){if(error.isEmpty())error="无法读取原生库压缩包";return false;}
        }return true;
    });
    bridge->setExternalLauncher(launcher);
    auto externalAccounts=new ExternalAccountController(APPLICATION->dataRoot()+"/auth",window);
    auto sources=new DownloadSources(APPLICATION->dataRoot(),window);
    auto quick=new QQuickWidget(window);
    quick->setResizeMode(QQuickWidget::SizeRootObjectToView);
    quick->engine()->addImageProvider("instances",new InstanceIcons);
    auto context=quick->rootContext();
    context->setContextProperty("desktop",bridge);
    context->setContextProperty("communityClient",community);
    context->setContextProperty("externalGames",external);
    context->setContextProperty("externalLauncher",launcher);
    context->setContextProperty("externalAccounts",externalAccounts);
    context->setContextProperty("downloadSources",sources);
    quick->setSource(QUrl("qrc:/deeraft/qml/Main.qml"));
    for(const auto& error:quick->errors())qWarning().noquote()<<error.toString();
    window->deeraftInstallCentral(quick);
    window->resize(1240,820);
    window->setMinimumSize(900,640);
    QTimer::singleShot(0,community,&CommunityClient::restoreSession);
    const QString capture=qEnvironmentVariable("DEERAFT_CAPTURE");
    if(!capture.isEmpty()){
        QTimer::singleShot(10000,window,[window,capture]{window->grab().save(capture);});
        QTimer::singleShot(11500,qApp,&QApplication::quit);
    }
    const QString smoke=qEnvironmentVariable("DEERAFT_SMOKE_DIR");
    if(!smoke.isEmpty() && quick->rootObject()){
        QDir().mkpath(smoke);
        auto take=[window,smoke](const QString& name){window->grab().save(QDir(smoke).filePath(name+".png"));};
        QTimer::singleShot(2500,window,[bridge,take]{bridge->setTheme("dark");take("community-dark");});
        QTimer::singleShot(3500,window,[quick]{quick->rootObject()->setProperty("page",1);});
        QTimer::singleShot(4500,window,[take]{take("launcher");});
        QTimer::singleShot(5500,window,[quick]{quick->rootObject()->setProperty("page",4);});
        QTimer::singleShot(6500,window,[take]{take("profile");});
        QTimer::singleShot(7500,window,[quick]{QMetaObject::invokeMethod(quick->rootObject(),"showSettings");});
        QTimer::singleShot(8500,window,[take]{take("settings");});
        QTimer::singleShot(9500,window,[quick,bridge]{QMetaObject::invokeMethod(quick->rootObject(),"closeSettings");quick->rootObject()->setProperty("page",0);bridge->setTheme("light");});
        QTimer::singleShot(10500,window,[take]{take("community-light");});
        QTimer::singleShot(11500,window,[window]{window->deeraftSetAdvanced(true);});
        QTimer::singleShot(12500,window,[take]{take("advanced");});
        QTimer::singleShot(13500,qApp,&QApplication::quit);
    }
}
