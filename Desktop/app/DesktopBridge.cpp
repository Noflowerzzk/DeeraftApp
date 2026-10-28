#include "DesktopBridge.h"
#include "Application.h"
#include "BaseInstance.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "minecraft/launch/MinecraftTarget.h"
#include <QDir>
#include <QFile>
#include <QDateTime>
#include <QJsonDocument>
#include "InstanceList.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/MinecraftAccount.h"
#include "tasks/Task.h"
#include "ui/MainWindow.h"
#include "compat/NativeExternalLaunchController.h"
#include "compat/ExternalGameCatalog.h"
#include "minecraft/auth/AuthFlow.h"
#include "minecraft/auth/AuthSession.h"
#include "settings/SettingsObject.h"
#include "ui/dialogs/ProgressDialog.h"
#include "webview/LivePlayer.h"
#include <QApplication>
#include <QDesktopServices>
#include <QFileDialog>
#include <QInputDialog>
#include <QMessageBox>
#include "library/DesktopLibrary.h"
#include <QPalette>
#include <QRegularExpression>
#include <QCryptographicHash>
#include "ui/themes/ThemeManager.h"
#include <QStyleHints>
#include <QStyleFactory>
#include <QTimer>
#include <QFutureWatcher>
#include <QtConcurrentRun>
#include <QElapsedTimer>

QPointer<DesktopBridge> DesktopBridge::s_instance;
DesktopBridge::DesktopBridge(MainWindow* window)
    : QObject(window), m_window(window), m_settings(APPLICATION->dataRoot()+"/desktop.ini",QSettings::IniFormat) {
    s_instance=this;
    if(!m_settings.value("windowsAppDefaultApplied").toBool()){
        APPLICATION->settings()->set("IconTheme","windowsapp");
        APPLICATION->themeManager()->setIconTheme("windowsapp");m_settings.setValue("windowsAppDefaultApplied",true);
    }
    for(const auto& style : {"Windows11", "windowsvista", "windows"}) {
        if(auto nativeStyle=QStyleFactory::create(style)) { qApp->setStyle(nativeStyle); qInfo()<<"Prism secondary style:"<<style; break; }
    }
    connect(APPLICATION,&Application::globalSettingsApplied,this,[this]{applyPalette();});
    connect(APPLICATION->instances(), &QAbstractItemModel::modelReset,this,&DesktopBridge::changed);
    connect(APPLICATION->instances(), &QAbstractItemModel::dataChanged,this,&DesktopBridge::changed);
    connect(APPLICATION->instances(), &QAbstractItemModel::rowsInserted,this,&DesktopBridge::changed);
    connect(APPLICATION->instances(), &QAbstractItemModel::rowsRemoved,this,&DesktopBridge::changed);
    connect(APPLICATION->accounts(), &AccountList::listChanged,this,&DesktopBridge::changed);
    connect(APPLICATION->accounts(), &AccountList::defaultAccountChanged,this,&DesktopBridge::changed);
    connect(qApp->styleHints(), &QStyleHints::colorSchemeChanged,this,[this]{applyPalette();emit themeChanged();});
    observeInstances();
    connect(APPLICATION->instances(),&QAbstractItemModel::rowsInserted,this,&DesktopBridge::observeInstances);
    connect(APPLICATION->instances(),&QAbstractItemModel::modelReset,this,&DesktopBridge::observeInstances);
    auto refresh=new QTimer(this);refresh->setInterval(10000);connect(refresh,&QTimer::timeout,this,&DesktopBridge::changed);refresh->start();
    applyPalette();
}
QVariantList DesktopBridge::instances() const {
    QVariantList result;
    auto list=APPLICATION->instances();
    for(int i=0;i<list->count();++i) {
        auto instance=list->at(i);
        QString version,loader;
        if(auto mc=qobject_cast<MinecraftInstance*>(instance)){auto profile=mc->getPackProfile();version=profile->getComponentVersion("net.minecraft");for(auto uid:{"net.fabricmc.fabric-loader","net.minecraftforge","net.neoforged","org.quiltmc.quilt-loader"}){auto value=profile->getComponentVersion(uid);if(!value.isEmpty()){QString label=QString(uid);label.replace("net.fabricmc.fabric-loader","Fabric").replace("net.minecraftforge","Forge").replace("net.neoforged","NeoForge").replace("org.quiltmc.quilt-loader","Quilt");loader=label+" "+value;break;}}}
        result.append(QVariantMap{{"id",instance->id()},{"name",instance->name()},
          {"description",instance->getStatusbarDescription()},{"icon",instance->iconKey()},
          {"version",version},{"loader",loader},{"external",false},{"source","native"},{"sourceName","DeeraftApp"},
          {"group",list->getInstanceGroup(instance->id())},{"seconds",instance->totalTimePlayed()},
          {"maxMemory",instance->settings()->get("MaxMemAlloc")},{"java",instance->settings()->get("JavaPath")},{"javaVersion",instance->settings()->get("JavaVersion")},
          {"lastPlayed",instance->lastLaunch()>0?QDateTime::fromMSecsSinceEpoch(instance->lastLaunch()).toString("M月d日 HH:mm"):QString()},{"running",instance->isRunning()},{"path",instance->gameRoot()},{"valid",true}});
    }
    return result;
}
QVariantList DesktopBridge::accounts() const {
    QVariantList result;
    auto list=APPLICATION->accounts();
    for(int i=0;i<list->count();++i) {
        auto account=list->at(i);
        result.append(QVariantMap{{"uuid",account->internalId()},{"name",account->profileName()},
          {"type",account->accountType()==AccountType::MSA?tr("正版登录"):account->accountType()==AccountType::Offline?tr("离线登录"):m_settings.value("accountLabels/"+account->internalId(),tr("第三方登录")).toString()},{"avatar",QString("image://accounts/")+account->internalId()+"?"+QString::fromLatin1(QCryptographicHash::hash(account->accountData()->minecraftProfile.skin.data,QCryptographicHash::Sha256).toHex().left(12))},{"selected",account==list->defaultAccount()}});
    }
    return result;
}
QFont DesktopBridge::interfaceFont() const {
    QFont font;
    font.setFamilies({"Roboto Flex","Noto Sans SC","Microsoft YaHei UI","Segoe UI"});
    font.setPixelSize(14);
    font.setStyleHint(QFont::SansSerif);
    font.setStyleStrategy(QFont::PreferTypoLineMetrics);
    return font;
}
QString DesktopBridge::theme() const { return m_settings.value("theme","system").toString(); }
bool DesktopBridge::dark() const { return theme()=="dark" || (theme()=="system" && qApp->styleHints()->colorScheme()==Qt::ColorScheme::Dark); }
void DesktopBridge::setTheme(const QString& value) {
    if(value!="system" && value!="light" && value!="dark") return;
    m_settings.setValue("theme",value);m_settings.sync();applyPalette();emit themeChanged();
}
void DesktopBridge::applyPalette() {
    // The QML window owns its Material palette. Secondary QWidget dialogs use
    // the Windows 11 style's own palette and system appearance.
    if(qApp->style()->objectName().compare("windows11",Qt::CaseInsensitive)!=0 && QStyleFactory::keys().contains("Windows11",Qt::CaseInsensitive))qApp->setStyle(QStyleFactory::create("Windows11"));
    auto hints=qApp->styleHints();
    const auto scheme=theme()=="system"?Qt::ColorScheme::Unknown:(theme()=="dark"?Qt::ColorScheme::Dark:Qt::ColorScheme::Light);
    hints->setColorScheme(scheme);
    qApp->setPalette(qApp->style()->standardPalette());
}
void DesktopBridge::action(const QString& name,const QString& id) {
 m_error.clear();
 auto instance=id.isEmpty()?nullptr:resolveInstance(id);
 auto lib=parent()->findChild<DesktopLibrary*>();
 if(name=="actionUndoTrashInstance" && lib){
    QString latest; qint64 timestamp=0;
    const auto values=lib->metadata();for(auto it=values.begin();it!=values.end();++it){const auto row=it.value().toMap();if(row.value("hidden").toBool() && row.value("removedAt").toLongLong()>timestamp){latest=it.key();timestamp=row.value("removedAt").toLongLong();}}
    if(!latest.isEmpty()){lib->setMetadata(latest,{{"hidden",false}});return;}
 }
 if(name=="actionRenameInstance" && instance){bool ok=false;const auto value=QInputDialog::getText(m_window->deeraftWindow(),tr("重命名实例"),tr("名称"),QLineEdit::Normal,instance->name(),&ok);if(ok && !value.trimmed().isEmpty()){instance->setName(value.trimmed());if(id.startsWith("external:")&&lib)lib->setMetadata(id,{{"name",value.trimmed()}});}emit changed();return;}
 if(name=="actionDeleteInstance" && instance && id.startsWith("external:") && lib){if(QMessageBox::question(m_window->deeraftWindow(),tr("移除实例"),tr("从实例列表移除 %1？游戏文件保留在：\n%2").arg(instance->name(),instance->gameRoot()))==QMessageBox::Yes)lib->setMetadata(id,{{"hidden",true},{"removedAt",QDateTime::currentMSecsSinceEpoch()}});return;}
 if(name=="actionLaunchInstanceOffline"){if(auto instance=resolveInstance(id))APPLICATION->launch(instance,LaunchMode::Offline);return;}
 if(name=="actionKillInstance"){if(auto instance=resolveInstance(id))APPLICATION->kill(instance);return;}
 if(name=="actionEditInstance"){if(auto instance=resolveInstance(id))APPLICATION->showInstanceWindow(instance,"settings");return;}
 if(name.startsWith("instance-page:")){if(auto instance=resolveInstance(id))APPLICATION->showInstanceWindow(instance,name.mid(14));return;}
 if(instance && id.startsWith("external:")){m_window->deeraftActionForInstance(name,instance);emit changed();return;}
 m_window->deeraftAction(name,id);
}
void DesktopBridge::selectInstance(const QString& id){m_window->deeraftSelectInstance(id);}
void DesktopBridge::advanced(){m_window->deeraftAction("actionSettings");}
QString DesktopBridge::chooseDirectory(){return QFileDialog::getExistingDirectory(m_window->deeraftWindow(),tr("选择游戏目录"));}
QUrl DesktopBridge::chooseFile(const QString& filter){auto path=QFileDialog::getOpenFileName(m_window->deeraftWindow(),tr("选择文件"),{},filter);return path.isEmpty()?QUrl():QUrl::fromLocalFile(path);}
void DesktopBridge::openPath(const QString& path){QDesktopServices::openUrl(QUrl::fromLocalFile(path));}
void DesktopBridge::openWebsite(){QDesktopServices::openUrl(QUrl("http://mc.ainfinitythecoder.cn/"));}
void DesktopBridge::openLive(const QString& roomId){showLivePlayer(m_window->deeraftWindow(),roomId,APPLICATION->dataRoot());}
void DesktopBridge::setExternalLauncher(Deeraft::NativeExternalLaunchController* launcher){
 setProperty("externalLauncher",QVariant::fromValue<QObject*>(launcher));
 connect(launcher,&Deeraft::NativeExternalLaunchController::started,this,[this,launcher]{emit gameStarted(launcher->versionId(),launcher->versionId().left(128));emit changed();});
 connect(launcher,&Deeraft::NativeExternalLaunchController::runningChanged,this,&DesktopBridge::changed);
}
void DesktopBridge::launchExternal(const QString& rootId,const QString& versionId,const QString& address,const QString& javaOverride){
    const QString id="external:"+rootId+":"+versionId;
    if(auto instance=resolveInstance(id)) {
        if(!javaOverride.isEmpty()){instance->settings()->set("OverrideJavaLocation",true);instance->settings()->set("JavaPath",javaOverride);}
        launchInstance(id,address);
    }else{m_error=tr("无法读取实例，请刷新实例目录");emit changed();}
}
void DesktopBridge::addOfflineAccount(const QString& name){
    if(!QRegularExpression("^[A-Za-z0-9_]{1,16}$").match(name).hasMatch()){m_error=tr("玩家名需为 1–16 位字母、数字或下划线");emit changed();return;}
    auto list=APPLICATION->accounts();
    if(list->getAccountByProfileName(name)){m_error=tr("该玩家已存在");emit changed();return;}
    auto account=MinecraftAccount::createOffline(name);
    if(account){list->addAccount(account);list->setDefaultAccount(account);m_error.clear();emit changed();}
}
void DesktopBridge::selectAccount(const QString& uuid){auto list=APPLICATION->accounts();for(int i=0;i<list->count();++i)if(list->at(i)->internalId()==uuid){list->setDefaultAccount(list->at(i));return;}}
void DesktopBridge::setAccountLabel(const QString& uuid,const QString& label){m_settings.setValue("accountLabels/"+uuid,label.trimmed().left(40));emit changed();}
void DesktopBridge::trackTask(Task* task){
    if(!s_instance || !task)return;
    auto self=s_instance.data();
    const QString id=task->getUid().toString();
    if(self->m_taskObjects.contains(id))return;
    self->m_taskObjects.insert(id,task);
    if(task->isRunning()||task->isFinished())self->updateTask(task);
    connect(task,&Task::started,self,[self,task]{self->updateTask(task,"进行中");});
    connect(task,&Task::progress,self,[self,task]{self->updateTask(task);});
    connect(task,&Task::status,self,[self,task]{self->updateTask(task);});
    connect(task,&Task::succeeded,self,[self,task]{self->updateTask(task,"完成");});
    connect(task,&Task::aborted,self,[self,task]{self->updateTask(task,"已取消");});
    connect(task,&Task::failed,self,[self,task]{self->updateTask(task,"失败");});
    connect(task,&QObject::destroyed,self,[self,id]{self->m_taskObjects.remove(id);for(auto& value:self->m_tasks){auto row=value.toMap();if(row.value("id")==id){row["canCancel"]=false;if(row.value("state")=="进行中"||row.value("state")=="等待")row["state"]="已结束";value=row;}}emit self->tasksChanged();});
}
void DesktopBridge::updateTask(Task* task,const QString& state){
    if(task->getState()==Task::State::Inactive)return;
    QString id=task->getUid().toString();int index=-1;
    for(int i=0;i<m_tasks.size();++i)if(m_tasks[i].toMap().value("id")==id){index=i;break;}
    QVariantMap row=index<0?QVariantMap{}:m_tasks[index].toMap();
    row.insert("id",id);row.insert("name",task->objectName());row.insert("status",task->getStatus());
    row.insert("current",task->getProgress());row.insert("total",task->getTotalProgress());row.insert("error",task->failReason());
    row.insert("canCancel",task->canAbort() && task->isRunning());
    if(!state.isEmpty())row.insert("state",state);
    switch(task->getState()){
      case Task::State::Running:row["state"]="进行中";break;
      case Task::State::Succeeded:row["state"]="完成";break;
      case Task::State::Failed:row["state"]="失败";break;
      case Task::State::AbortedByUser:row["state"]="已取消";break;
      default:break;
    }
    if(index<0)m_tasks.prepend(row);else m_tasks[index]=row;
    while(m_tasks.size()>100){int expired=-1;for(int i=m_tasks.size()-1;i>=0;--i)if(m_tasks[i].toMap().value("state")!="进行中"){expired=i;break;}if(expired<0)break;m_tasks.removeAt(expired);}
    emit tasksChanged();
}
void DesktopBridge::cancelTask(const QString& id){if(auto task=m_taskObjects.value(id);task && task->canAbort())task->abort();}

void DesktopBridge::launchInstance(const QString& id,const QString& address){
 auto instance=resolveInstance(id);if(!instance)return;
 if(instance->isRunning()){m_error=tr("该实例正在运行，请在游戏内加入服务器");emit changed();return;}
 MinecraftTarget::Ptr target;
 if(!address.isEmpty()){auto url=QUrl("mc://"+address);if(url.host().isEmpty()){m_error=tr("服务器地址无效");emit changed();return;}target=std::make_shared<MinecraftTarget>(MinecraftTarget::parse(address,false));}
 APPLICATION->launch(instance,LaunchMode::Normal,target);
}
namespace {
QVariantList readResourceFolder(const QString& folder,const QString& kind){
 if(kind!="mods"&&kind!="saves"&&kind!="screenshots"&&kind!="resourcepacks"&&kind!="shaderpacks")return {};
 QVariantList result;auto entries=QDir(folder).entryInfoList(kind=="saves"?QDir::Dirs|QDir::NoDotAndDotDot:QDir::Files,QDir::Name|QDir::IgnoreCase);
 for(const auto& file:entries){if(kind=="mods"){QString name=file.fileName();if(name.endsWith(".disabled"))name.chop(9);if(!QStringList{"jar","zip","litemod"}.contains(QFileInfo(name).suffix().toLower()))continue;}if(kind=="screenshots"&&!QStringList{"png","jpg","jpeg","webp"}.contains(file.suffix().toLower()))continue;result.append(QVariantMap{{"name",file.fileName()},{"path",file.absoluteFilePath()},{"url",QUrl::fromLocalFile(file.absoluteFilePath())},{"enabled",!file.fileName().endsWith(".disabled")},{"size",file.size()},{"updated",file.lastModified().toString("yyyy-MM-dd HH:mm")}});}return result;
}
}
QVariantList DesktopBridge::resources(const QString& id,const QString& kind) const{
 auto instance=resolveInstance(id);if(!instance)return {};
 return readResourceFolder(kind=="mods"?instance->modsRoot():QDir(instance->gameRoot()).filePath(kind),kind);
}
void DesktopBridge::loadResources(const QString& id){
 const auto ticket=++m_resourceRequest;
 QElapsedTimer clock;clock.start();auto instance=resolveInstance(id);
 if(!instance){emit resourcesLoaded(id,{});return;}
 const auto mods=instance->modsRoot(),game=instance->gameRoot();
 if(qEnvironmentVariableIsSet("DEERAFT_IMPORT_DIRECTORY"))qInfo()<<"Directory instance prepared in"<<clock.elapsed()<<"ms";
 auto watcher=new QFutureWatcher<QVariantMap>(this);
 connect(watcher,&QFutureWatcher<QVariantMap>::finished,this,[this,watcher,ticket,id]{const auto rows=watcher->result();watcher->deleteLater();if(ticket==m_resourceRequest)emit resourcesLoaded(id,rows);});
 watcher->setFuture(QtConcurrent::run([mods,game]{return QVariantMap{{"mods",readResourceFolder(mods,"mods")},{"saves",readResourceFolder(QDir(game).filePath("saves"),"saves")},{"screenshots",readResourceFolder(QDir(game).filePath("screenshots"),"screenshots")}};}));
}
bool DesktopBridge::setModEnabled(const QString& id,const QString& fileName,bool enabled){
 auto instance=resolveInstance(id);if(!instance||instance->isRunning()||QFileInfo(fileName).fileName()!=fileName)return false;
 auto folder=QDir(instance->modsRoot());auto path=folder.filePath(fileName);if(!QFileInfo(path).isFile()||QFileInfo(path).isSymLink())return false;
 QString target=fileName;if(enabled&&target.endsWith(".disabled"))target.chop(9);else if(!enabled&&!target.endsWith(".disabled"))target+=".disabled";if(target==fileName)return true;
 if(!QFile::rename(path,folder.filePath(target))){m_error=tr("无法修改模组状态");emit changed();return false;}return true;
}
QString DesktopBridge::readGameLog(const QString& id)const{auto instance=resolveInstance(id);if(!instance)return {};QFile file(QDir(instance->gameRoot()).filePath("logs/latest.log"));if(!file.open(QIODevice::ReadOnly))return {};if(file.size()>262144)file.seek(file.size()-262144);return QString::fromUtf8(file.readAll());}

void DesktopBridge::observeInstances(){for(int i=0;i<APPLICATION->instances()->count();++i){auto instance=APPLICATION->instances()->at(i);if(m_observed.contains(instance))continue;m_observed.insert(instance);connect(instance,&QObject::destroyed,this,[this,instance]{m_observed.remove(instance);});connect(instance,&BaseInstance::minecraftStarted,this,[this,instance]{QString version;if(auto mc=qobject_cast<MinecraftInstance*>(instance))version=mc->getPackProfile()->getComponentVersion("net.minecraft");emit gameStarted(instance->name(),version);emit changed();});}}
