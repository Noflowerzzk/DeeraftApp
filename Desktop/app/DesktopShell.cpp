#include "DesktopShell.h"
#include "DesktopWindow.h"
#include "DesktopTranslations.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/MinecraftAccount.h"
#include <QtQml/QQmlExtensionPlugin>
Q_IMPORT_QML_PLUGIN(Qcm_MaterialPlugin)
Q_IMPORT_QML_PLUGIN(Qcm_Material_LayoutsPlugin)
#include "DesktopBridge.h"
#include "update/AppUpdater.h"
#include "library/DesktopLibrary.h"
#include "net/ApiDownload.h"
#include "net/ChecksumValidator.h"
#include "net/NetJob.h"
#include <QCloseEvent>
#include <QJsonDocument>
#include <QJsonArray>
#include <QTextLayout>
#include <QGlyphRun>
#include <QToolBar>
#include <QDialog>
#include <QMouseEvent>
#include <QKeyEvent>
#include <QQmlComponent>
#include <QJsonObject>
#include <QCryptographicHash>
#include "community/CommunityClient.h"
#include "compat/ExternalGameCatalog.h"
#include "compat/NativeExternalLaunchController.h"
#include "accounts/ExternalAccountController.h"
#include "download/DownloadSources.h"
#include "archive/ArchiveReader.h"
#include "archive/ExportToZipTask.h"
#include "InstanceCopyTask.h"
#include "InstanceList.h"
#include "settings/INIFile.h"
#include "settings/SettingsObject.h"
#include "Application.h"
#include "ui/MainWindow.h"
#include "icons/IconList.h"
#include <QApplication>
#include <QFontDatabase>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickImageProvider>
#include <QQuickView>
#include <QQuickItem>
#include <QQuickStyle>
#include <QTimer>
#include <QElapsedTimer>
#include <QFile>
#include <QSaveFile>
#include <QDir>
#include <QDesktopServices>
#include <QCoreApplication>
#include <QPainter>
#include <functional>
#include "DesktopPolishProbe.h"
#include "DesktopFeedbackProbe.h"
#include "DesktopLaunchAudit.h"

class InstanceIcons final : public QQuickImageProvider {
public:
    InstanceIcons():QQuickImageProvider(QQuickImageProvider::Pixmap){}
    QPixmap requestPixmap(const QString& id,QSize* size,const QSize& requested) override {
        QSize target=requested.isValid()?requested:QSize(64,64);
        if(size)*size=target;
        return APPLICATION->icons()->getIcon(id).pixmap(target);
    }
};
class AccountFaces final : public QQuickImageProvider {
public:
    AccountFaces():QQuickImageProvider(QQuickImageProvider::Pixmap){}
    QPixmap requestPixmap(const QString& id,QSize* size,const QSize& requested) override {
        const auto target=requested.isValid()?requested:QSize(64,64);if(size)*size=target;
        auto list=APPLICATION->accounts();
        for(int i=0;i<list->count();++i)if(list->at(i)->internalId()==id.section('?',0,0)){
            auto account=list->at(i);auto face=account->getFace(target.width(),target.height());
            if(face.isNull() && !m_requested.contains(account->internalId()) && (account->accountType()==AccountType::Authlib||account->accountType()==AccountType::YggdrasilConnect)){
                m_requested.insert(account->internalId());QTimer::singleShot(0,account.get(),[account]{if(!account->currentTask())account->refresh();});
            }
            if(face.isNull()){
                face=QPixmap(target);face.fill(QColor("#cde7df"));QPainter painter(&face);painter.setRenderHint(QPainter::Antialiasing);painter.setBrush(QColor("#42675d"));painter.setPen(Qt::NoPen);
                painter.drawEllipse(QRectF(target.width()*.34,target.height()*.18,target.width()*.32,target.height()*.32));
                painter.drawRoundedRect(QRectF(target.width()*.2,target.height()*.57,target.width()*.6,target.height()*.3),target.width()*.1,target.height()*.1);
            }
            return face;
        }
        return {};
    }
private:
    QSet<QString> m_requested;
};
void installDeeraftShell(MainWindow* window){
    Q_INIT_RESOURCE(deeraft);
    const auto language=APPLICATION->settings()->get("Language").toString();
    QLocale::setDefault(QLocale(language.startsWith("zh")?"zh_CN":language));
    qApp->installTranslator(new ChineseCatalog(qApp));
    qApp->installTranslator(new DesktopTranslations(qApp));
    qputenv("QT_SHADER_CACHE_PATH",QFile::encodeName(APPLICATION->dataRoot()+"/cache/shaders"));
    qputenv("QML_DISK_CACHE_PATH",QFile::encodeName(APPLICATION->dataRoot()+"/cache/qml"));
    QQuickStyle::setStyle("Basic");
    auto host=new DesktopWindow(window);
    window->deeraftSetWindow(host);
    const int hanFont=QFontDatabase::addApplicationFont(":/deeraft/fonts/NotoSansSC.ttf");
    QFontDatabase::addApplicationFallbackFontFamily(QChar::Script_Han,"Noto Sans SC");
    QFontDatabase::addApplicationFallbackFontFamily(QChar::Script_Common,"Noto Sans SC");
    if(!qEnvironmentVariable("DEERAFT_SMOKE_DIR").isEmpty())qInfo()<<"CJK font families:"<<QFontDatabase::applicationFontFamilies(hanFont);
    QFontDatabase::addApplicationFont(":/deeraft/fonts/MaterialSymbolsRounded.ttf");
    QFontDatabase::addApplicationFont(":/deeraft/fonts/RobotoFlex.ttf");
    QFont applicationFont;applicationFont.setFamilies({"Segoe UI","Noto Sans SC"});applicationFont.setPointSize(10);qApp->setFont(applicationFont);
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
    bridge->loadInstanceDirectories();
    QObject::connect(external,&Deeraft::ExternalGameCatalog::versionsChanged,bridge,&DesktopBridge::loadInstanceDirectories);
    host->setExternalLauncher(launcher);
    auto externalAccounts=new ExternalAccountController(APPLICATION->dataRoot()+"/auth",window);
    auto updater=new AppUpdater(APPLICATION->dataRoot(),window);
    auto sources=new DownloadSources(APPLICATION->dataRoot(),window);
    auto quick=new QQuickView;
    quick->setResizeMode(QQuickView::SizeRootObjectToView);
    quick->engine()->addImportPath("qrc:/");
    quick->engine()->addImageProvider("instances",new InstanceIcons);
    quick->engine()->addImageProvider("accounts",new AccountFaces);
    auto context=quick->rootContext();
    context->setContextProperty("appRoot",quick->contentItem());
    context->setContextProperty("windowChrome",host);
    context->setContextProperty("desktop",bridge);
    context->setContextProperty("library",library);
    context->setContextProperty("communityClient",community);
    context->setContextProperty("externalGames",external);
    context->setContextProperty("externalLauncher",launcher);
    context->setContextProperty("externalAccounts",externalAccounts);
    context->setContextProperty("downloadSources",sources);
    context->setContextProperty("appUpdater",updater);
    const QString visualFixture=qEnvironmentVariable("DEERAFT_SMOKE_DIR").isEmpty()?QString():qEnvironmentVariable("DEERAFT_DESIGN_FIXTURE");
    QJsonObject fixtureData;
    if(!visualFixture.isEmpty()) {
        QFile file(QDir(visualFixture).filePath("fixture.json"));
        if(file.open(QIODevice::ReadOnly))fixtureData=QJsonDocument::fromJson(file.readAll()).object();
        QQmlComponent component(quick->engine(),QUrl::fromLocalFile(QDir(visualFixture).filePath("FixtureClient.qml")));
        if(auto fixture=component.create(context)){
            fixture->setParent(window);fixture->setProperty("dataset",fixtureData.toVariantMap());context->setContextProperty("communityClient",fixture);
        }else for(const auto& error:component.errors())qWarning().noquote()<<error.toString();
    }
    const QString liveQml=qEnvironmentVariable("DEERAFT_SMOKE_DIR").isEmpty()?QString():qEnvironmentVariable("DEERAFT_QML_DIR");
    quick->setSource(liveQml.isEmpty()?QUrl("qrc:/deeraft/qml/Main.qml"):QUrl::fromLocalFile(QDir(liveQml).filePath("Main.qml")));
    for(const auto& error:quick->errors())qWarning().noquote()<<error.toString();
    if(!quick->rootObject()&&!qEnvironmentVariable("DEERAFT_SMOKE_DIR").isEmpty()){QTimer::singleShot(0,qApp,[]{qApp->exit(1);});return;}
    if(!fixtureData.isEmpty()&&quick->rootObject())quick->rootObject()->setProperty("visualInstances",fixtureData.value("instances").toArray().toVariantList());
    host->setContent(quick);
    QTimer::singleShot(0,community,&CommunityClient::restoreSession);
    const QString capture=qEnvironmentVariable("DEERAFT_CAPTURE");
    if(!capture.isEmpty()){
        QTimer::singleShot(10000,window,[quick,capture]{quick->grabWindow().save(capture);});
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
        auto report=std::make_shared<QJsonObject>();
        auto writeReport=[report,smoke]{QSaveFile file(QDir(smoke).filePath("native-checks.json"));if(file.open(QIODevice::WriteOnly)){file.write(QJsonDocument(*report).toJson());file.commit();}};
        QTextLayout text(QString::fromUtf8("社区 启动器 在线玩家"),bridge->interfaceFont());text.beginLayout();auto line=text.createLine();line.setLineWidth(600);text.endLayout();
        QJsonArray fontFamilies;for(const auto& run:text.glyphRuns())fontFamilies.append(run.rawFont().familyName());(*report)["cjkGlyphFonts"]=fontFamilies;
        auto take=[quick,smoke](const QString& name){if(name=="secondary-settings"){for(auto widget:qApp->topLevelWidgets())if(widget->isVisible()&&qobject_cast<QDialog*>(widget)){widget->grab().save(QDir(smoke).filePath(name+".png"));return;}}quick->grabWindow().save(QDir(smoke).filePath(name+".png"));};
        auto item=[quick](const char* name){return quick->rootObject()->findChild<QQuickItem*>(QString::fromUtf8(name));};
        auto click=[quick,item](const char* name){if(auto target=item(name)){auto point=target->mapToItem(quick->rootObject(),QPointF(target->width()/2,target->height()/2));QMouseEvent press(QEvent::MouseButtonPress,point,quick->mapToGlobal(point.toPoint()),Qt::LeftButton,Qt::LeftButton,Qt::NoModifier);QApplication::sendEvent(quick,&press);QMouseEvent release(QEvent::MouseButtonRelease,point,quick->mapToGlobal(point.toPoint()),Qt::LeftButton,Qt::NoButton,Qt::NoModifier);QApplication::sendEvent(quick,&release);}};
        auto escape=[quick]{QKeyEvent press(QEvent::KeyPress,Qt::Key_Escape,Qt::NoModifier);QApplication::sendEvent(quick,&press);QKeyEvent release(QEvent::KeyRelease,Qt::Key_Escape,Qt::NoModifier);QApplication::sendEvent(quick,&release);};
        const auto importDirectory=qEnvironmentVariable("DEERAFT_IMPORT_DIRECTORY");
        if(qEnvironmentVariable("DEERAFT_UPDATE_PROBE")=="1"){
            QObject::connect(updater,&AppUpdater::changed,window,[updater,smoke]{if(updater->busy()||updater->status().isEmpty())return;const bool ok=updater->latest()==updater->version()&&!updater->available();QSaveFile file(smoke+"/update-check.json");if(file.open(QIODevice::WriteOnly)){file.write(QJsonDocument(QJsonObject{{"success",ok},{"version",updater->version()},{"latest",updater->latest()},{"status",updater->status()},{"automatic",updater->automatic()},{"kernel","11.1.1"}}).toJson());file.commit();}qApp->exit(ok?0:1);});
            QTimer::singleShot(0,updater,&AppUpdater::check);QTimer::singleShot(20000,window,[]{qApp->exit(2);});return;
        }
        if(startDesktopLaunchAudit(bridge,external,window,smoke))return;
        if(startFeedbackProbe(quick,bridge,external,window,smoke))return;
        if(startPolishProbe(quick,host,bridge,external,window,smoke))return;
        if(!importDirectory.isEmpty()){
            auto elapsed=std::make_shared<QElapsedTimer>();auto pulse=std::make_shared<QElapsedTimer>();
            auto heartbeat=new QTimer(window);heartbeat->setInterval(20);
            QObject::connect(heartbeat,&QTimer::timeout,window,[report,pulse]{const auto gap=pulse->restart();(*report)["maximumUiGapMs"]=std::max(report->value("maximumUiGapMs").toInt(),int(gap));(*report)["heartbeatCount"]=report->value("heartbeatCount").toInt()+1;});
            const auto invalid=std::make_shared<QStringList>();const auto index=std::make_shared<int>(0);
            const auto empty=QDir(smoke).filePath("empty/.minecraft");QDir().mkpath(empty+"/versions");
            const auto malformed=QDir(smoke).filePath("malformed/.minecraft");QDir().mkpath(malformed+"/versions/bad");QFile bad(malformed+"/versions/bad/bad.json");if(bad.open(QIODevice::WriteOnly))bad.write("broken json");
            invalid->append(QDir(smoke).filePath("missing"));invalid->append(empty);invalid->append(malformed);
            for(const auto& name:QDir(importDirectory).entryList(QDir::Dirs|QDir::NoDotAndDotDot))if(QFileInfo::exists(importDirectory+"/"+name+"/mmc-pack.json")){invalid->append(importDirectory+"/"+name);invalid->append(importDirectory+"/"+name+"/mmc-pack.json");break;}
            auto next=std::make_shared<std::function<void()>>();
            *next=[external,invalid,index,report,writeReport,bridge,library,take,window]{
                if(*index<invalid->size()){external->addRootAsync(invalid->at((*index)++));return;}
                (*report)["rootsAfterInvalidSelections"]=external->roots().size();(*report)["rowsAfterInvalidSelections"]=library->externalInstances().size();
                (*report)["nativeDirectoryObjects"]=bridge->externalStates().size();(*report)["scanningFinished"]=!external->scanning();
                take("import-directory");writeReport();QTimer::singleShot(0,window,[]{qApp->quit();});
            };
            QObject::connect(external,&Deeraft::ExternalGameCatalog::importFailed,window,[external,report,library,next,window](const QString& path,const QString& message){
                QJsonArray failures=report->value("invalidSelections").toArray();failures.append(QJsonObject{{"path",path},{"message",message}});(*report)["invalidSelections"]=failures;
                (*report)["invalidSelectionPreservedRows"]=report->value("invalidSelectionPreservedRows").toBool(true)&&external->roots().size()==1&&library->externalInstances().size()==report->value("importedCount").toInt();
                QTimer::singleShot(30,window,[next]{if(*next)(*next)();});
            });
            QObject::connect(external,&Deeraft::ExternalGameCatalog::importFinished,window,[elapsed,report,quick,window](const QString&,int count){
                (*report)["importedCount"]=count;(*report)["importElapsedMs"]=int(elapsed->elapsed());
                QTimer::singleShot(300,window,[quick,report]{(*report)["worldTabRequested"]=true;if(auto page=quick->rootObject()->findChild<QObject*>("launcherPage")){page->setProperty("detailTab",2);QMetaObject::invokeMethod(page,"reloadFiles");(*report)["explicitResourceRefresh"]=true;}});
            });
            QObject::connect(bridge,&DesktopBridge::resourcesLoaded,window,[quick,report,heartbeat,next,take,window](const QString&,const QVariantMap& rows){
                if(!report->value("worldTabRequested").toBool()||report->value("worldCheckStarted").toBool())return;
                (*report)["worldCheckStarted"]=true;(*report)["worldDataCount"]=rows.value("saves").toList().size();
                QTimer::singleShot(100,window,[quick]{if(auto list=quick->rootObject()->findChild<QObject*>("worldList")){QMetaObject::invokeMethod(list,"forceLayout");QMetaObject::invokeMethod(list,"positionViewAtEnd");}});
                QTimer::singleShot(350,window,[quick,report,heartbeat,next,take]{
                    heartbeat->stop();take("worlds-virtualized");
                    if(auto list=quick->rootObject()->findChild<QQuickItem*>("worldList")){
                        int count=0;std::function<void(QQuickItem*)> visit=[&](QQuickItem* item){if(item->objectName()=="worldRow")++count;for(auto child:item->childItems())visit(child);};visit(list);
                        (*report)["worldModelCount"]=list->property("count").toInt();(*report)["realizedWorldRows"]=count;(*report)["worldScrollY"]=list->property("contentY").toDouble();(*report)["worldContentHeight"]=list->property("contentHeight").toDouble();(*report)["worldViewportHeight"]=list->height();
                    }
                    if(*next)(*next)();
                });
            });
            QTimer::singleShot(1200,window,[external,library,importDirectory,elapsed,pulse,heartbeat,report]{
                (*report)["startupRowsBeforeImport"]=library->externalInstances().size();pulse->start();heartbeat->start();elapsed->start();
                external->addRootAsync(importDirectory);(*report)["requestReturnedMs"]=int(elapsed->elapsed());
            });
            QTimer::singleShot(20000,window,[report,writeReport]{(*report)["timedOut"]=true;writeReport();qApp->exit(1);});
            return;
        }
        if(qEnvironmentVariableIsSet("DEERAFT_REPAIR_PROBE")){
            // Controlled fixtures only: no original launcher directories or account files are written.
            const auto source=QDir(smoke).filePath("source-game");
            auto put=[](const QString& path,const QByteArray& bytes){QDir().mkpath(QFileInfo(path).absolutePath());QFile file(path);return file.open(QIODevice::WriteOnly)&&file.write(bytes)==bytes.size();};
            const auto version=source+"/versions/测试版本";
            put(version+"/测试版本.json",R"({"id":"fixture","clientVersion":"1.17.1","patches":[{"id":"game","version":"1.17.1"},{"id":"fabric","version":"0.17.3"}]})");
            put(version+"/hmclversion.cfg",R"({"usesGlobal":false,"gameDirType":1,"unknown":"preserve"})");
            put(version+"/mods/test.jar","fixture");put(version+"/saves/测试世界/level.dat","fixture");
            const auto rootId=external->addRoot(source);const auto instanceId="external:"+rootId+":测试版本";
            auto instance=bridge->resolveDirectoryReference(instanceId);
            const auto state=bridge->externalStates().value(instanceId).toMap();
            (*report)["directoryCoreRegistered"]=instance!=nullptr;
            (*report)["directoryVersion"]=state.value("version").toString();(*report)["directoryLoader"]=state.value("loader").toString();
            (*report)["directoryMods"]=bridge->resources(instanceId,"mods").size();(*report)["directoryWorlds"]=bridge->resources(instanceId,"saves").size();
            (*report)["modToggleRoundTrip"]=bridge->setModEnabled(instanceId,"test.jar",false)&&QFileInfo::exists(version+"/mods/test.jar.disabled")&&bridge->setModEnabled(instanceId,"test.jar.disabled",true);
            if(instance){
                instance->settings()->set("DeeraftGameDirectory",version);
                const auto staging=QDir(smoke).filePath("copy-result");
                InstanceCopyPrefs prefs;prefs.enableCopyMods(false);
                auto copy=new InstanceCopyTask(instance,prefs);copy->setParent(window);copy->setParentSettings(APPLICATION->settings());copy->setStagingPath(staging);copy->setName("Fixture copy");
                QObject::connect(copy,&Task::succeeded,window,[report,staging,version]{
                    INIFile config;config.loadFile(staging+"/instance.cfg");
                    (*report)["copyWorldPreserved"]=QFileInfo::exists(staging+"/minecraft/saves/测试世界/level.dat");
                    (*report)["copyModFilterRespected"]=!QFileInfo::exists(staging+"/minecraft/mods/test.jar");
                    (*report)["copyIndependentDirectory"]=!config.contains("DeeraftGameDirectory");
                    (*report)["copyOriginalIntact"]=QFileInfo::exists(version+"/mods/test.jar")&&QFileInfo::exists(version+"/saves/测试世界/level.dat");
                });copy->start();
                const auto output=QDir(smoke).filePath("mapped-export.zip");
                auto archive=new MMCZip::ExportToZipTask(output,version,QFileInfoList{QFileInfo(version+"/mods/test.jar"),QFileInfo(instance->instanceRoot()+"/mmc-pack.json")},"minecraft/");archive->setParent(window);
                archive->mapFilePath(instance->instanceRoot()+"/mmc-pack.json","mmc-pack.json");archive->addExtraFile("instance.cfg","[General]\nname=Fixture\n");
                QObject::connect(archive,&Task::succeeded,window,[report,output]{MMCZip::ArchiveReader reader(output);reader.collectFiles();const auto files=reader.getFiles();(*report)["exportPortablePaths"]=files.contains("minecraft/mods/test.jar")&&files.contains("mmc-pack.json")&&files.contains("instance.cfg")&&!files.join('|').contains("../");});archive->start();
            }
            QTimer::singleShot(1200,window,[host,quick,report]{
                (*report)["viewport"]=QJsonObject{{"hostWidth",host->width()},{"viewWidth",quick->width()},{"rootWidth",quick->rootObject()->width()},{"rootHeight",quick->rootObject()->height()},{"ownerless",host->parentWidget()==nullptr},{"hasIcon",!host->windowIcon().isNull()}};
                quick->rootObject()->setProperty("page",0);
            });
            QTimer::singleShot(2200,window,[quick,item,take,report]{
                take("long-motd");
                auto hero=item("serverHero"),button=item("heroLaunchButton");
                if(hero&&button){const auto pos=button->mapToItem(hero,QPointF());(*report)["motdLaunchInsideHero"]=pos.y()>=0&&pos.y()+button->height()<=hero->height();}
                quick->rootObject()->setProperty("page",2);
            });
            QTimer::singleShot(3000,window,[item]{if(auto page=item("serversPage"))page->setProperty("onlyRunning",true);});
            QTimer::singleShot(3500,window,[quick,item,take,report]{
                take("running-servers");int count=0;
                std::function<void(QQuickItem*)> visit=[&](QQuickItem* node){if(node->objectName()=="serverCard"&&node->isVisible()&&node->property("running").toBool())++count;for(auto child:node->childItems())visit(child);};
                if(auto page=item("serversPage"))visit(page);
                (*report)["runningServerCards"]=count;quick->rootObject()->setProperty("page",4);
            });
            QTimer::singleShot(4200,window,[quick]{if(auto calendar=quick->rootObject()->findChild<QObject*>("dailyCalendar"))QMetaObject::invokeMethod(calendar,"open");});
            QTimer::singleShot(4800,window,[quick,take,report]{
                take("date-picker");QJsonArray labels;
                std::function<void(QQuickItem*)> visit=[&](QQuickItem* node){const auto text=node->property("text").toString();if(node->isVisible()&&!text.isEmpty())labels.append(text);for(auto child:node->childItems())visit(child);};visit(quick->contentItem());
                (*report)["calendarVisibleLabels"]=labels;
                if(auto calendar=quick->rootObject()->findChild<QObject*>("dailyCalendar")){(*report)["calendarPosition"]=QJsonObject{{"x",calendar->property("x").toDouble()},{"y",calendar->property("y").toDouble()},{"width",calendar->property("width").toDouble()},{"height",calendar->property("height").toDouble()}};QMetaObject::invokeMethod(calendar,"close");}
                quick->rootObject()->setProperty("page",1);
            });
            QTimer::singleShot(5500,window,[quick,take,click,item,report]{
                take("running-instance");if(auto launch=item("launchGame"))(*report)["runningButtonText"]=launch->property("text").toString();
                const auto shot=quick->grabWindow();bool filled=true;
                for(auto name:{"sourcePicker","groupPicker"})if(auto field=item(name)){
                    auto background=field->property("background").value<QQuickItem*>();
                    if(!background||background->childItems().isEmpty()){filled=false;continue;}
                    const auto expected=background->childItems().first()->property("color").value<QColor>();
                    const auto pos=field->mapToItem(quick->rootObject(),QPointF(3,30));const auto scale=shot.width()/quick->rootObject()->width();
                    const auto observed=shot.pixelColor(qRound(pos.x()*scale),qRound(pos.y()*scale));
                    filled&=expected.isValid()&&std::abs(expected.red()-observed.red())<5&&std::abs(expected.green()-observed.green())<5&&std::abs(expected.blue()-observed.blue())<5;
                }
                (*report)["selectorFillSurvivesPageTransitions"]=filled;click("libraryMenuButton");
            });
            QTimer::singleShot(6100,window,[quick,take,report]{
                take("library-menu");auto menu=quick->rootObject()->findChild<QObject*>("libraryMenu");if(menu)(*report)["libraryMenuWidth"]=menu->property("width").toDouble();
            });
            QTimer::singleShot(6500,window,escape);
            QTimer::singleShot(6900,window,[click]{click("sourcePicker");});
            QTimer::singleShot(7400,window,[take]{take("source-menu");});
            QTimer::singleShot(7700,window,escape);
            QTimer::singleShot(8000,window,[bridge,instanceId]{bridge->action("actionEditInstance",instanceId);});
            QTimer::singleShot(9300,window,[smoke,report]{for(auto widget:qApp->topLevelWidgets())if(widget->isVisible()&&widget->inherits("InstanceWindow")){widget->grab().save(QDir(smoke).filePath("directory-settings.png"));(*report)["nativeInstanceSettingsOpened"]=true;widget->close();}});
            QTimer::singleShot(9600,window,[quick]{
                if(auto fixture=quick->rootContext()->contextProperty("communityClient").value<QObject*>()){fixture->setProperty("uploading",true);fixture->setProperty("uploadProgress",.37);}
                if(auto drawer=quick->rootObject()->findChild<QObject*>("downloadTasks"))QMetaObject::invokeMethod(drawer,"open");
            });
            QTimer::singleShot(11200,window,[quick,take,report]{take("wavy-progress");QJsonArray bars;std::function<void(QQuickItem*)> visit=[&](QQuickItem* node){if(node->isVisible()&&node->property("wavy").toBool())bars.append(QJsonObject{{"value",node->property("value").toDouble()},{"displayed",node->property("displayedPosition").toDouble()},{"amplitude",node->property("amplitudeFraction").toDouble()},{"animating",node->property("animating").toBool()},{"width",node->width()},{"height",node->height()}});for(auto child:node->childItems())visit(child);};visit(quick->contentItem());(*report)["visibleWavyIndicators"]=bars.size();(*report)["progressIndicators"]=bars;});
            QTimer::singleShot(11700,window,[report,writeReport,host]{(*report)["appToolbarCount"]=host->findChildren<QToolBar*>().size();writeReport();qApp->quit();});
            return;
        }
        if(qEnvironmentVariableIsSet("DEERAFT_MOTION_PROBE")) {
            auto captureRail=[quick,report](const QString& name){
                QJsonArray rows;
                QList<QQuickItem*> icons;
                std::function<void(QQuickItem*)> visit=[&](QQuickItem* item){
                    if(item->objectName()=="railItemIcon")icons.append(item);
                    for(auto child:item->childItems())visit(child);
                };
                visit(quick->rootObject());
                for(auto icon:icons) {
                    auto owner=icon->parentItem() ? icon->parentItem()->parentItem() : nullptr;
                    if(!owner || !owner->isVisible())continue;
                    auto background=owner->findChild<QQuickItem*>("railIndicatorBounds");
                    if(!background)continue;
                    const auto a=icon->mapToItem(quick->rootObject(),{icon->width()/2,icon->height()/2});
                    const auto b=background->mapToItem(quick->rootObject(),{background->width()/2,background->height()/2});
                    rows.append(QJsonObject{{"label",owner->property("text").toString()},{"dx",a.x()-b.x()},{"dy",a.y()-b.y()}});
                }
                (*report)[name]=rows;
            };
            auto frameProbe=new QTimer(window);
            frameProbe->setInterval(25);
            QObject::connect(frameProbe,&QTimer::timeout,window,[quick,report,take]{
                auto motion=quick->rootObject()->findChild<QObject*>("pageMotion");
                if(!motion)return;
                auto target=qvariant_cast<QQuickItem*>(motion->property("target"));
                if(!target || !motion->property("running").toBool())return;
                const bool exiting=quick->rootObject()->property("displayedPage").toInt()==1;
                const auto key=exiting ? "outgoingFrameCaptured" : "incomingFrameCaptured";
                if(!report->value(key).toBool() && target->opacity()>.05 && target->opacity()<.95){
                    (*report)[key]=true;
                    take(exiting ? "exit-observed" : "enter-observed");
                }
            });
            frameProbe->start();
            QTimer::singleShot(1200,window,[take,captureRail]{take("rail-collapsed");captureRail("railCollapsedCenters");});
            QTimer::singleShot(1500,window,[quick]{quick->rootObject()->setProperty("page",0);});
            QTimer::singleShot(1545,window,[take]{take("page-exit");});
            QTimer::singleShot(1640,window,[take]{take("page-enter");});
            QTimer::singleShot(1950,window,[take,quick,report]{take("page-settled");(*report)["pageSettled"]=quick->rootObject()->property("displayedPage").toInt()==0;});
            QTimer::singleShot(2100,window,[quick]{quick->rootObject()->setProperty("page",2);});
            QTimer::singleShot(2120,window,[quick]{quick->rootObject()->setProperty("page",4);});
            QTimer::singleShot(2140,window,[quick]{quick->rootObject()->setProperty("page",1);});
            QTimer::singleShot(2600,window,[quick,report]{(*report)["rapidNavigationLastRequestWins"]=quick->rootObject()->property("displayedPage").toInt()==1;});
            QTimer::singleShot(2750,window,[quick]{quick->rootObject()->setProperty("railExpanded",true);});
            QTimer::singleShot(3350,window,[take,captureRail]{take("rail-expanded");captureRail("railExpandedCenters");});
            QTimer::singleShot(3550,window,[quick]{
                if(auto page=quick->rootObject()->findChild<QObject*>("launcherPage")) {
                    QMetaObject::invokeMethod(page,"selectInstance",Q_ARG(QVariant,QVariant("ctf")));
                }
            });
            QTimer::singleShot(3595,window,[take]{take("instance-exit");});
            QTimer::singleShot(3690,window,[take]{take("instance-enter");});
            QTimer::singleShot(4000,window,[quick,report]{
                if(auto page=quick->rootObject()->findChild<QObject*>("launcherPage"))(*report)["instanceSwapSettled"]=page->property("selectedId").toString()=="ctf";
                if(auto motion=quick->rootObject()->findChild<QObject*>("pageMotion"))motion->setProperty("reducedMotion",true);
                quick->rootObject()->setProperty("page",2);
                (*report)["reducedMotionImmediate"]=quick->rootObject()->property("displayedPage").toInt()==2;
            });
            QTimer::singleShot(4300,window,[take,writeReport]{take("reduced-motion");writeReport();qApp->quit();});
            return;
        }
        QTimer::singleShot(1100,window,[window,host,quick,report,item,writeReport]{
            QMetaObject::invokeMethod(window,"defaultAccountChanged",Qt::DirectConnection);
            QMetaObject::invokeMethod(window,"globalSettingsClosed",Qt::DirectConnection);
            (*report)["legacyWindowHiddenAfterAccountChange"]=!window->isVisible();(*report)["appToolbarCount"]=host->findChildren<QToolBar*>().size();
            (*report)["viewport"]=QJsonObject{{"hostWidth",host->width()},{"hostHeight",host->height()},{"viewWidth",quick->width()},{"viewHeight",quick->height()},{"rootWidth",quick->rootObject()->width()},{"rootHeight",quick->rootObject()->height()},{"contentWidth",quick->contentItem()->width()},{"ownerless",host->parentWidget()==nullptr},{"hasIcon",!host->windowIcon().isNull()}};
            QJsonObject geometry;for(auto name:{"instanceLibrary","instanceSearch","sourcePicker","instanceDetail","instanceCover","instanceTitle","launchGame","detailTabs"})if(auto target=item(name)){auto p=target->mapToItem(quick->rootObject(),QPointF());geometry[name]=QJsonObject{{"x",p.x()},{"y",p.y()},{"width",target->width()},{"height",target->height()}};}(*report)["geometry"]=geometry;writeReport();
        });
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
        QTimer::singleShot(13500,window,[]{for(auto widget:qApp->topLevelWidgets())if(auto dialog=qobject_cast<QDialog*>(widget);dialog&&dialog->isVisible())dialog->reject();});
        QTimer::singleShot(14000,window,[quick,bridge]{quick->rootObject()->setProperty("page",1);bridge->setTheme("light");});
        QTimer::singleShot(14500,window,[click]{click("sourcePicker");});
        QTimer::singleShot(14900,window,[take,item,report,writeReport]{take("source-menu");if(auto target=item("sourcePicker"))(*report)["sourceMenuOpened"]=target->property("popupVisible").toBool();writeReport();});
        QTimer::singleShot(15200,window,escape);
        QTimer::singleShot(15600,window,[click]{click("libraryMenuButton");});
        QTimer::singleShot(16000,window,[take]{take("library-menu");});
        QTimer::singleShot(16300,window,escape);
        QTimer::singleShot(16800,window,[quick]{quick->rootObject()->setProperty("railExpanded",true);});
        QTimer::singleShot(17500,window,[take]{take("rail-expanded");});
        QTimer::singleShot(18000,window,[quick]{quick->rootObject()->setProperty("railExpanded",false);});
        QTimer::singleShot(18700,window,[take,writeReport]{take("launcher-final");writeReport();});
        QTimer::singleShot(19500,qApp,&QApplication::quit);
    }
}
