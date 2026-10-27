#include "DesktopBridge.h"
#include "Application.h"
#include "BaseInstance.h"
#include "InstanceList.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/MinecraftAccount.h"
#include "tasks/Task.h"
#include "ui/MainWindow.h"
#include "compat/NativeExternalLaunchController.h"
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
    applyPalette();
}
QVariantList DesktopBridge::instances() const {
    QVariantList result;
    auto list=APPLICATION->instances();
    for(int i=0;i<list->count();++i) {
        auto instance=list->at(i);
        result.append(QVariantMap{{"id",instance->id()},{"name",instance->name()},
          {"description",instance->getStatusbarDescription()},{"icon",instance->iconKey()},
          {"running",instance->isRunning()},{"path",instance->gameRoot()}});
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
    p.setColor(QPalette::Window,QColor(d?"#101712":"#f5faf4"));
    p.setColor(QPalette::Base,QColor(d?"#18201a":"#ffffff"));
    p.setColor(QPalette::AlternateBase,QColor(d?"#202b22":"#eaf1e8"));
    p.setColor(QPalette::WindowText,QColor(d?"#e1e9df":"#18211a"));
    p.setColor(QPalette::Text,p.color(QPalette::WindowText));
    p.setColor(QPalette::Button,QColor(d?"#253329":"#e3ecdf"));
    p.setColor(QPalette::ButtonText,p.color(QPalette::WindowText));
    p.setColor(QPalette::Highlight,QColor(d?"#9ad4ab":"#356b4a"));
    p.setColor(QPalette::HighlightedText,QColor(d?"#07391c":"#ffffff"));
    p.setColor(QPalette::ToolTipBase,p.color(QPalette::Base));
    p.setColor(QPalette::ToolTipText,p.color(QPalette::Text));
    p.setColor(QPalette::Disabled,QPalette::Text,QColor(d?"#8a958b":"#748074"));
    qApp->setPalette(p);
}
void DesktopBridge::action(const QString& name,const QString& id) {m_window->deeraftAction(name,id);}
void DesktopBridge::advanced(){m_window->deeraftSetAdvanced(true);}
QString DesktopBridge::chooseDirectory(){return QFileDialog::getExistingDirectory(m_window,tr("选择游戏目录"));}
QUrl DesktopBridge::chooseFile(const QString& filter){auto path=QFileDialog::getOpenFileName(m_window,tr("选择文件"),{},filter);return path.isEmpty()?QUrl():QUrl::fromLocalFile(path);}
void DesktopBridge::openPath(const QString& path){QDesktopServices::openUrl(QUrl::fromLocalFile(path));}
void DesktopBridge::openWebsite(){QDesktopServices::openUrl(QUrl("http://mc.ainfinitythecoder.cn/"));}
void DesktopBridge::openLive(const QString& roomId){showLivePlayer(m_window,roomId,APPLICATION->dataRoot());}
void DesktopBridge::setExternalLauncher(Deeraft::NativeExternalLaunchController* launcher){setProperty("externalLauncher",QVariant::fromValue<QObject*>(launcher));}
void DesktopBridge::launchExternal(const QString& rootId,const QString& versionId){
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
    auto settings=APPLICATION->settings();QString java=settings->get("JavaPath").toString();
    if(java.isEmpty())java=m_settings.value("externalJavaPath").toString();
    if(java.isEmpty()){
        java=QFileDialog::getOpenFileName(m_window,tr("选择 Java 可执行文件"),{},"Java (java.exe javaw.exe)");
        if(java.isEmpty()) return;
        m_settings.setValue("externalJavaPath",java);
    }
    QStringList jvm=QProcess::splitCommand(settings->get("JvmArgs").toString());jvm.append(session->extraJvmArguments);
    QVariantMap identity{{"playerName",session->player_name},{"uuid",session->uuid},{"accessToken",session->access_token.isEmpty()?"0":session->access_token},{"userType",session->user_type},{"session",session->session},{"userProperties",session->serializeUserProperties()}};
    QVariantMap options{{"javaPath",java},{"minMemoryMiB",settings->get("MinMemAlloc")},{"maxMemoryMiB",settings->get("MaxMemAlloc")},{"jvmArguments",jvm}};
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
