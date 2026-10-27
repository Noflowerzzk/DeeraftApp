#include "DesktopShell.h"
#include "DesktopBridge.h"
#include "library/DesktopLibrary.h"
#include "net/ApiDownload.h"
#include "net/ChecksumValidator.h"
#include "net/NetJob.h"
#include <QCloseEvent>
#include <QJsonDocument>
#include <QJsonObject>
#include <QCryptographicHash>
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

// Keep ownership of the directory lock until the external JVM exits.
// Closing the window minimizes it instead of destroying a running game process.
class ExternalGameWindowGuard final:public QObject {
public:
 ExternalGameWindowGuard(QWidget* window,Deeraft::NativeExternalLaunchController* launcher):QObject(window),m_window(window),m_launcher(launcher){}
 bool eventFilter(QObject*,QEvent* event)override{
  if(event->type()==QEvent::Close&&m_launcher&&m_launcher->running()){static_cast<QCloseEvent*>(event)->ignore();QTimer::singleShot(0,m_window,[this]{m_window->showMinimized();});return true;}return false;
 }
private:QWidget* m_window;QPointer<Deeraft::NativeExternalLaunchController> m_launcher;
};
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
    qputenv("QML_DISK_CACHE_PATH",QFile::encodeName(APPLICATION->dataRoot()+"/cache/qml"));
    QQuickStyle::setStyle("Material");
    QFontDatabase::addApplicationFont(":/deeraft/fonts/NotoSansSC.ttf");
    QFontDatabase::addApplicationFont(":/deeraft/fonts/MaterialSymbolsRounded.ttf");
    QFontDatabase::addApplicationFont(":/deeraft/fonts/RobotoFlex.ttf");
    QFont applicationFont;applicationFont.setFamilies({"Roboto Flex","Noto Sans SC"});applicationFont.setPointSize(10);qApp->setFont(applicationFont);
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
    auto library=new DesktopLibrary(APPLICATION->dataRoot(),external,window);
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
    window->installEventFilter(new ExternalGameWindowGuard(window,launcher));
    auto externalAccounts=new ExternalAccountController(APPLICATION->dataRoot()+"/auth",window);
    auto sources=new DownloadSources(APPLICATION->dataRoot(),window);
    auto quick=new QQuickWidget(window);
    quick->setResizeMode(QQuickWidget::SizeRootObjectToView);
    quick->engine()->addImageProvider("instances",new InstanceIcons);
    auto context=quick->rootContext();
    context->setContextProperty("desktop",bridge);
    context->setContextProperty("library",library);
    context->setContextProperty("communityClient",community);
    context->setContextProperty("externalGames",external);
    context->setContextProperty("externalLauncher",launcher);
    context->setContextProperty("externalAccounts",externalAccounts);
    context->setContextProperty("downloadSources",sources);
    quick->setSource(QUrl("qrc:/deeraft/qml/Main.qml"));
    for(const auto& error:quick->errors())qWarning().noquote()<<error.toString();
    window->deeraftInstallCentral(quick);
    window->resize(1440,960);
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
        const QString fixtureAccount=qEnvironmentVariable("DEERAFT_SMOKE_ACCOUNT");
        if(!fixtureAccount.isEmpty())bridge->addOfflineAccount(fixtureAccount);
        const QString probeFile=qEnvironmentVariable("DEERAFT_SOURCE_PROBE");
        if(!probeFile.isEmpty()){
            const QString hash="9dd32387135eefa7ab95996d52a5ca4cec8a3b30";
            auto [download,bytes]=Net::ApiDownload::makeByteArray(QUrl("https://resources.download.minecraft.net/9d/"+hash));
            download->addValidator(new Net::ChecksumValidator(QCryptographicHash::Sha1,hash));
            auto report=std::make_shared<QJsonObject>();
            QObject::connect(download.get(),&Task::status,window,[report](const QString& status){if(status.contains("bmclapi2.bangbang93.com"))(*report)["domesticAttempted"]=true;if(status.contains("resources.download.minecraft.net"))(*report)["officialAttempted"]=true;});
            auto job=new NetJob("Deeraft source verification",APPLICATION->network());job->setParent(window);job->addNetAction(download);
            auto finish=[report,bytes,hash,probeFile](bool success){(*report)["success"]=success;(*report)["sha1Matches"]=QString::fromLatin1(QCryptographicHash::hash(*bytes,QCryptographicHash::Sha1).toHex())==hash;QSaveFile file(probeFile);if(file.open(QIODevice::WriteOnly)){file.write(QJsonDocument(*report).toJson());file.commit();}QTimer::singleShot(0,qApp,[success]{qApp->exit(success?0:1);});};
            QObject::connect(job,&Task::succeeded,window,[finish]{finish(true);});QObject::connect(job,&Task::failed,window,[finish](const QString&){finish(false);});
            QTimer::singleShot(1000,job,&Task::start);QTimer::singleShot(90000,window,[finish]{finish(false);});return;
        }
        auto take=[window,smoke](const QString& name){window->grab().save(QDir(smoke).filePath(name+".png"));};
        QTimer::singleShot(1500,window,[take]{take("launcher-light");});
        QTimer::singleShot(2000,window,[quick,bridge]{quick->rootObject()->setProperty("page",0);bridge->setTheme("dark");});
        QTimer::singleShot(3000,window,[take]{take("community-dark");});
        QTimer::singleShot(3500,window,[quick]{quick->rootObject()->setProperty("page",1);});
        QTimer::singleShot(4500,window,[take]{take("launcher-dark");});
        QTimer::singleShot(5000,window,[quick]{quick->rootObject()->setProperty("page",2);});
        QTimer::singleShot(5500,window,[take]{take("servers-dark");});
        QTimer::singleShot(6000,window,[quick]{quick->rootObject()->setProperty("page",4);});
        QTimer::singleShot(6500,window,[take]{take("profile");});
        QTimer::singleShot(6800,window,[quick]{quick->rootObject()->setProperty("page",3);});
        QTimer::singleShot(7300,window,[take]{take("chat");});
        QTimer::singleShot(7500,window,[quick]{QMetaObject::invokeMethod(quick->rootObject(),"showSettings");});
        QTimer::singleShot(8500,window,[take]{take("settings");});
        QTimer::singleShot(9500,window,[quick,bridge]{QMetaObject::invokeMethod(quick->rootObject(),"closeSettings");quick->rootObject()->setProperty("page",0);bridge->setTheme("light");});
        QTimer::singleShot(10500,window,[take]{take("community-light");});
        QTimer::singleShot(11500,window,[window]{window->deeraftSetAdvanced(true);});
        QTimer::singleShot(12500,window,[take]{take("secondary-settings");});
        QTimer::singleShot(13500,qApp,&QApplication::quit);
    }
}
