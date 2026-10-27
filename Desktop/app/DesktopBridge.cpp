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
#include <QPalette>
#include <QRegularExpression>
#include <QStyleHints>
#include <QStyleFactory>
#include <QTimer>

QPointer<DesktopBridge> DesktopBridge::s_instance;
DesktopBridge::DesktopBridge(MainWindow* window)
    : QObject(window), m_window(window), m_settings(APPLICATION->dataRoot()+"/desktop.ini",QSettings::IniFormat) {
    s_instance=this;
    qApp->setStyle(QStyleFactory::create("Fusion"));
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
          {"maxMemory",instance->settings()->get("MaxMemAlloc")},{"java",instance->settings()->get("JavaPath")},
          {"running",instance->isRunning()},{"path",instance->gameRoot()},{"valid",true}});
    }
    return result;
}
QVariantList DesktopBridge::accounts() const {
    QVariantList result;
    auto list=APPLICATION->accounts();
    for(int i=0;i<list->count();++i) {
        auto account=list->at(i);
        result.append(QVariantMap{{"uuid",account->profileId()},{"name",account->profileName()},
          {"type",account->typeString()},{"selected",account==list->defaultAccount()}});
    }
    return result;
}
QString DesktopBridge::theme() const { return m_settings.value("theme","system").toString(); }
bool DesktopBridge::dark() const { return theme()=="dark" || (theme()=="system" && qApp->styleHints()->colorScheme()==Qt::ColorScheme::Dark); }
void DesktopBridge::setTheme(const QString& value) {
    if(value!="system" && value!="light" && value!="dark") return;
    m_settings.setValue("theme",value);m_settings.sync();applyPalette();emit themeChanged();
}
void DesktopBridge::applyPalette() {
    QPalette p;
    const bool d=dark();
    p.setColor(QPalette::Window,QColor(d?"#0e1512":"#f5fbf7"));
    p.setColor(QPalette::Base,QColor(d?"#171d1b":"#ffffff"));
    p.setColor(QPalette::AlternateBase,QColor(d?"#202b22":"#eff5f1"));
    p.setColor(QPalette::WindowText,QColor(d?"#dce5df":"#171d1b"));
    p.setColor(QPalette::Text,p.color(QPalette::WindowText));
    p.setColor(QPalette::Button,QColor(d?"#334b45":"#cde8e0"));
    p.setColor(QPalette::ButtonText,p.color(QPalette::WindowText));
    p.setColor(QPalette::Highlight,QColor(d?"#84d6c3":"#056b5b"));
    p.setColor(QPalette::HighlightedText,QColor(d?"#00382d":"#ffffff"));
    p.setColor(QPalette::ToolTipBase,p.color(QPalette::Base));
    p.setColor(QPalette::ToolTipText,p.color(QPalette::Text));
    p.setColor(QPalette::Disabled,QPalette::Text,QColor(d?"#8a958b":"#748074"));
    qApp->setPalette(p);
}
void DesktopBridge::action(const QString& name,const QString& id) {
 m_error.clear();
 if(name=="actionLaunchInstanceOffline"){if(auto instance=APPLICATION->instances()->getInstanceById(id))APPLICATION->launch(instance,LaunchMode::Offline);return;}
 if(name.startsWith("instance-page:")){if(auto instance=APPLICATION->instances()->getInstanceById(id))APPLICATION->showInstanceWindow(instance,name.mid(14));return;}
 m_window->deeraftAction(name,id);
}
void DesktopBridge::selectInstance(const QString& id){m_window->deeraftSelectInstance(id);}
void DesktopBridge::advanced(){m_window->deeraftAction("actionSettings");}
QString DesktopBridge::chooseDirectory(){return QFileDialog::getExistingDirectory(m_window,tr("选择游戏目录"));}
QUrl DesktopBridge::chooseFile(const QString& filter){auto path=QFileDialog::getOpenFileName(m_window,tr("选择文件"),{},filter);return path.isEmpty()?QUrl():QUrl::fromLocalFile(path);}
void DesktopBridge::openPath(const QString& path){QDesktopServices::openUrl(QUrl::fromLocalFile(path));}
void DesktopBridge::openWebsite(){QDesktopServices::openUrl(QUrl("http://mc.ainfinitythecoder.cn/"));}
void DesktopBridge::openLive(const QString& roomId){showLivePlayer(m_window,roomId,APPLICATION->dataRoot());}
void DesktopBridge::setExternalLauncher(Deeraft::NativeExternalLaunchController* launcher){
 setProperty("externalLauncher",QVariant::fromValue<QObject*>(launcher));
 connect(launcher,&Deeraft::NativeExternalLaunchController::started,this,[this,launcher]{emit gameStarted(launcher->versionId(),launcher->versionId().left(128));emit changed();});
 connect(launcher,&Deeraft::NativeExternalLaunchController::runningChanged,this,&DesktopBridge::changed);
}
void DesktopBridge::launchExternal(const QString& rootId,const QString& versionId,const QString& address,const QString& javaOverride){
    auto launcher=qobject_cast<Deeraft::NativeExternalLaunchController*>(property("externalLauncher").value<QObject*>());
    auto account=APPLICATION->accounts()->defaultAccount();
    if(!launcher || !account){m_error=tr("请先在设置中添加并选择 Minecraft 账号");emit changed();return;}
    if(account->accountType()!=AccountType::Offline){
        if(account->shouldRefresh() || account->accountState()!=AccountState::Online){
            account->refresh();auto task=account->currentTask();if(task){ProgressDialog progress(m_window);progress.execWithTask(task.get());}
        }
        if(account->accountState()!=AccountState::Online || !account->ownsMinecraft()){m_error=tr("账号无法用于启动，请重新登录或选择离线账号");emit changed();return;}
    }
    auto session=std::make_shared<AuthSession>();session->launchMode=account->accountType()==AccountType::Offline?LaunchMode::Offline:LaunchMode::Normal;account->fillSession(session);
    if((account->accountType()==AccountType::Authlib || account->accountType()==AccountType::YggdrasilConnect) && session->extraJvmArguments.isEmpty()){m_error=tr("认证组件校验失败，请重新添加账号");emit changed();return;}
    auto settings=APPLICATION->settings();QString java=javaOverride;if(QUrl(java).isLocalFile())java=QUrl(java).toLocalFile();if(java.isEmpty())java=settings->get("JavaPath").toString();
    if(java.isEmpty())java=m_settings.value("externalJavaPath").toString();
    if(java.isEmpty()){
        java=QFileDialog::getOpenFileName(m_window,tr("选择 Java 可执行文件"),{},"Java (java.exe javaw.exe)");
        if(java.isEmpty()) return;
        m_settings.setValue("externalJavaPath",java);
    }
    QStringList jvm=QProcess::splitCommand(settings->get("JvmArgs").toString());jvm.append(session->extraJvmArguments);
    QVariantMap identity{{"playerName",session->player_name},{"uuid",session->uuid},{"accessToken",session->access_token.isEmpty()?"0":session->access_token},{"userType",session->user_type},{"session",session->session},{"userProperties",session->serializeUserProperties()}};
    QVariantMap options{{"javaPath",java},{"minMemoryMiB",settings->get("MinMemAlloc")},{"maxMemoryMiB",settings->get("MaxMemAlloc")},{"jvmArguments",jvm}};
    if(!address.isEmpty()){
        auto key=QUrl("mc://"+address);if(key.host().isEmpty()){m_error=tr("服务器地址无效");emit changed();return;}
        // Modern versions declare quickPlay in their manifest; legacy versions use server/port.
        auto externalCatalog=m_window->findChild<Deeraft::ExternalGameCatalog*>();
        auto resolved=externalCatalog?externalCatalog->resolveVersion(rootId,versionId):QVariantMap{};
        auto json=QJsonDocument::fromVariant(resolved.value("versionJson")).toJson();
        options["gameArguments"]=json.contains("quickPlayMultiplayer")?QStringList{"--quickPlayMultiplayer",address}:QStringList{"--server",key.host(),"--port",QString::number(key.port(25565))};
    }
    m_error.clear();if(!launcher->launch(rootId,versionId,identity,options))m_error=launcher->error();emit changed();
}
void DesktopBridge::addOfflineAccount(const QString& name){
    if(!QRegularExpression("^[A-Za-z0-9_]{1,16}$").match(name).hasMatch()){m_error=tr("玩家名需为 1–16 位字母、数字或下划线");emit changed();return;}
    auto list=APPLICATION->accounts();
    if(list->getAccountByProfileName(name)){m_error=tr("该玩家已存在");emit changed();return;}
    auto account=MinecraftAccount::createOffline(name);
    if(account){list->addAccount(account);list->setDefaultAccount(account);m_error.clear();emit changed();}
}
void DesktopBridge::selectAccount(const QString& uuid){auto list=APPLICATION->accounts();int i=list->findAccountByProfileId(uuid);if(i>=0)list->setDefaultAccount(list->at(i));}
void DesktopBridge::trackTask(Task* task){
    if(!s_instance || !task)return;
    auto self=s_instance.data();
    const QString id=task->getUid().toString();
    if(self->m_taskObjects.contains(id))return;
    self->m_taskObjects.insert(id,task);
    self->updateTask(task,"等待");
    connect(task,&Task::started,self,[self,task]{self->updateTask(task,"进行中");});
    connect(task,&Task::progress,self,[self,task]{self->updateTask(task);});
    connect(task,&Task::status,self,[self,task]{self->updateTask(task);});
    connect(task,&Task::succeeded,self,[self,task]{self->updateTask(task,"完成");});
    connect(task,&Task::aborted,self,[self,task]{self->updateTask(task,"已取消");});
    connect(task,&Task::failed,self,[self,task]{self->updateTask(task,"失败");});
}
void DesktopBridge::updateTask(Task* task,const QString& state){
    QString id=task->getUid().toString();int index=-1;
    for(int i=0;i<m_tasks.size();++i)if(m_tasks[i].toMap().value("id")==id){index=i;break;}
    QVariantMap row=index<0?QVariantMap{}:m_tasks[index].toMap();
    row.insert("id",id);row.insert("name",task->objectName());row.insert("status",task->getStatus());
    row.insert("current",task->getProgress());row.insert("total",task->getTotalProgress());row.insert("error",task->failReason());
    row.insert("canCancel",task->canAbort() && !task->isFinished());
    if(!state.isEmpty())row.insert("state",state);
    if(index<0)m_tasks.prepend(row);else m_tasks[index]=row;
    while(m_tasks.size()>100)m_tasks.removeLast();
    emit tasksChanged();
}
void DesktopBridge::cancelTask(const QString& id){if(auto task=m_taskObjects.value(id);task && task->canAbort())task->abort();}

void DesktopBridge::launchInstance(const QString& id,const QString& address){
 auto instance=APPLICATION->instances()->getInstanceById(id);if(!instance)return;
 if(instance->isRunning()){m_error=tr("该实例正在运行，请在游戏内加入服务器");emit changed();return;}
 MinecraftTarget::Ptr target;
 if(!address.isEmpty()){auto url=QUrl("mc://"+address);if(url.host().isEmpty()){m_error=tr("服务器地址无效");emit changed();return;}target=std::make_shared<MinecraftTarget>(MinecraftTarget::parse(address,false));}
 APPLICATION->launch(instance,LaunchMode::Normal,target);
}
QVariantList DesktopBridge::resources(const QString& id,const QString& kind) const{
 auto instance=APPLICATION->instances()->getInstanceById(id);if(!instance)return {};
 QString folder=kind=="mods"?instance->modsRoot():QDir(instance->gameRoot()).filePath(kind);
 if(kind!="mods"&&kind!="saves"&&kind!="screenshots"&&kind!="resourcepacks"&&kind!="shaderpacks")return {};
 QVariantList result;auto entries=QDir(folder).entryInfoList(kind=="saves"?QDir::Dirs|QDir::NoDotAndDotDot:QDir::Files,QDir::Name|QDir::IgnoreCase);
 for(const auto& file:entries){if(kind=="mods"){QString name=file.fileName();if(name.endsWith(".disabled"))name.chop(9);if(!QStringList{"jar","zip","litemod"}.contains(QFileInfo(name).suffix().toLower()))continue;}if(kind=="screenshots"&&!QStringList{"png","jpg","jpeg","webp"}.contains(file.suffix().toLower()))continue;result.append(QVariantMap{{"name",file.fileName()},{"path",file.absoluteFilePath()},{"url",QUrl::fromLocalFile(file.absoluteFilePath())},{"enabled",!file.fileName().endsWith(".disabled")},{"size",file.size()},{"updated",file.lastModified().toString("yyyy-MM-dd HH:mm")}});}return result;
}
bool DesktopBridge::setModEnabled(const QString& id,const QString& fileName,bool enabled){
 auto instance=APPLICATION->instances()->getInstanceById(id);if(!instance||instance->isRunning()||QFileInfo(fileName).fileName()!=fileName)return false;
 auto folder=QDir(instance->modsRoot());auto path=folder.filePath(fileName);if(!QFileInfo(path).isFile()||QFileInfo(path).isSymLink())return false;
 QString target=fileName;if(enabled&&target.endsWith(".disabled"))target.chop(9);else if(!enabled&&!target.endsWith(".disabled"))target+=".disabled";if(target==fileName)return true;
 if(!QFile::rename(path,folder.filePath(target))){m_error=tr("无法修改模组状态");emit changed();return false;}emit changed();return true;
}
QString DesktopBridge::readGameLog(const QString& id)const{auto instance=APPLICATION->instances()->getInstanceById(id);if(!instance)return {};QFile file(QDir(instance->gameRoot()).filePath("logs/latest.log"));if(!file.open(QIODevice::ReadOnly))return {};if(file.size()>262144)file.seek(file.size()-262144);return QString::fromUtf8(file.readAll());}

void DesktopBridge::observeInstances(){for(int i=0;i<APPLICATION->instances()->count();++i){auto instance=APPLICATION->instances()->at(i);if(m_observed.contains(instance))continue;m_observed.insert(instance);connect(instance,&QObject::destroyed,this,[this,instance]{m_observed.remove(instance);});connect(instance,&BaseInstance::minecraftStarted,this,[this,instance]{QString version;if(auto mc=qobject_cast<MinecraftInstance*>(instance))version=mc->getPackProfile()->getComponentVersion("net.minecraft");emit gameStarted(instance->name(),version);emit changed();});}}
