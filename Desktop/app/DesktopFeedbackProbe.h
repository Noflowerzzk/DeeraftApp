#pragma once
#ifdef Q_OS_WIN
#include <windows.h>
#include <shobjidl.h>
#include <propkey.h>
#undef OPTIONAL
#endif
// Focused, isolated UI acceptance. Geometry uses reduced motion; actual springs are unit tested.
class FeedbackTask final:public Task {
public:
 void executeTask()override{}
 bool canAbort()const override{return true;}
 bool abort()override{emitAborted();return true;}
 void advance(qint64 current,qint64 total){setProgress(current,total);}
 void fail(){emitFailed("测试请求失败");}
};
inline bool startFeedbackProbe(QQuickView* quick,DesktopBridge* bridge,Deeraft::ExternalGameCatalog* catalog,QObject* owner,const QString& output){
 if(qEnvironmentVariable("DEERAFT_FEEDBACK_PROBE")!="1")return false;
 auto root=quick->rootObject();auto report=std::make_shared<QJsonObject>();
 auto find=[quick,root](const char* name){QQuickItem* found=nullptr;std::function<void(QQuickItem*)> visit=[&](QQuickItem* node){if(node->objectName()==QString::fromUtf8(name))found=node;for(auto child:node->childItems())visit(child);};visit(quick->contentItem());return found?found:root->findChild<QQuickItem*>(name);};
 auto rows=[root]{auto value=root->property("visibleTasks");if(value.metaType()==QMetaType::fromType<QJSValue>())value=value.value<QJSValue>().toVariant();return value.toList();};
 auto capture=[quick,output](const QString& name){quick->grabWindow().save(output+"/"+name+".png");};
 auto active=new FeedbackTask;active->setObjectName("资源下载");active->setParent(owner);DesktopBridge::trackTask(active);active->start();active->advance(43,183);
 auto failed=new FeedbackTask;failed->setObjectName("失败任务");failed->setParent(owner);DesktopBridge::trackTask(failed);failed->start();failed->fail();
 auto hasFailed=[rows,failed]{for(const auto& row:rows())if(row.toMap()["id"].toString()==failed->getUid().toString())return true;return false;};
 auto library=quick->rootContext()->contextProperty("library").value<QObject*>();
 const auto games=output+"/fixtures/.minecraft";QDir().mkpath(games+"/versions/1.20.1");QFile file(games+"/versions/1.20.1/1.20.1.json");file.open(QIODevice::WriteOnly);file.write("{\"id\":\"1.20.1\",\"type\":\"release\"}");file.close();catalog->addRoot(games);
 auto phase=std::make_shared<int>(0);auto elapsed=std::make_shared<QElapsedTimer>();elapsed->start();auto timer=new QTimer(owner);timer->setInterval(50);
 QObject::connect(timer,&QTimer::timeout,owner,[=]{
  quick->grabWindow();
  if(*phase==0&&elapsed->elapsed()>300){
   (*report)["activeShapeVisible"]=find("activeTasksLoading")&&find("activeTasksLoading")->isVisible();
   (*report)["failedArchived"]=!hasFailed();root->setProperty("showCompletedTasks",true);(*report)["failedInHistory"]=hasFailed();root->setProperty("showCompletedTasks",false);
   if(library)library->setProperty("reducedMotion",true);QMetaObject::invokeMethod(root->findChild<QObject*>("downloadTasks"),"open");elapsed->restart();*phase=1;
  }else if(*phase==1&&elapsed->elapsed()>250){
   if(elapsed->elapsed()<3000&&(!find("taskPercentage")||find("taskPercentage")->property("text").toString()!="23%"))return;
   (*report)["percentage23"]=find("taskPercentage")&&find("taskPercentage")->property("text").toString()=="23%";capture("task-progress");
   bridge->cancelTask(active->getUid().toString());QMetaObject::invokeMethod(root->findChild<QObject*>("downloadTasks"),"close");elapsed->restart();*phase=2;
  }else if(*phase==2&&elapsed->elapsed()>200){
   (*report)["idleShapeHidden"]=find("activeTasksLoading")&&!find("activeTasksLoading")->isVisible();bridge->setTheme("dark");
   if(auto input=find("offlinePlayerName"))input->setProperty("text","OfflineTest");QMetaObject::invokeMethod(root,"showSettings");elapsed->restart();*phase=3;
  }else if(*phase==3&&elapsed->elapsed()>250){
   if(auto scroll=find("settingsScroll"))if(auto flick=scroll->property("contentItem").value<QQuickItem*>())flick->setProperty("contentY",350.);capture("outlined-inputs-dark");QMetaObject::invokeMethod(root,"closeSettings");elapsed->restart();*phase=4;
  }else if(*phase==4&&elapsed->elapsed()>150){
   QMetaObject::invokeMethod(root->findChild<QObject*>("rootsDialog"),"open");elapsed->restart();*phase=5;
  }else if(*phase==5&&elapsed->elapsed()>250){
   (*report)["darkDirectoryText"]=find("rootsHeading")&&find("rootsHeading")->property("color").value<QColor>()==root->property("ink").value<QColor>();capture("roots-dark");QMetaObject::invokeMethod(root->findChild<QObject*>("rootsDialog"),"close");root->setProperty("page",3);elapsed->restart();*phase=6;
  }else if(*phase==6&&elapsed->elapsed()>200){
   auto chat=find("chatPage");if(!chat)return;chat->setProperty("searchOpen",true);if(auto query=find("chatSearchField"))query->setProperty("searchText","服务器");elapsed->restart();*phase=7;
  }else if(*phase==7&&elapsed->elapsed()>150){
   auto chat=find("chatPage");auto values=chat->property("filtered").value<QJSValue>().toVariant().toList();(*report)["searchFilters"]=values.size()==1;chat->setProperty("searchOpen",false);
   (*report)["closingSearchClearsQuery"]=find("chatSearchField")&&find("chatSearchField")->property("searchText").toString().isEmpty();
   chat->setProperty("searchOpen",true);DesktopBridge::showNotice("可用内存偏低，可在实例设置中调整内存。");elapsed->restart();*phase=8;
  }else if(*phase==8&&elapsed->elapsed()>250){
   (*report)["noticeVisible"]=find("appNotification")&&find("appNotification")->isVisible();capture("chat-notice");
   auto host=qobject_cast<QWidget*>(quick->rootContext()->contextProperty("windowChrome").value<QObject*>());
   (*report)["nativeWindowFrame"]=host&&!host->windowFlags().testFlag(Qt::FramelessWindowHint)&&!find("appTitleBar");
#ifdef Q_OS_WIN
   PWSTR processId=nullptr;const auto idResult=GetCurrentProcessExplicitAppUserModelID(&processId);
   (*report)["taskbarProcessIdentity"]=SUCCEEDED(idResult)&&QString::fromWCharArray(processId)=="cn.ainfinity.DeeraftApp";CoTaskMemFree(processId);
   IPropertyStore* store=nullptr;bool windowIdentity=false,taskbarIcon=false;
   if(host&&SUCCEEDED(SHGetPropertyStoreForWindow(reinterpret_cast<HWND>(host->winId()),IID_PPV_ARGS(&store)))){
    PROPVARIANT value;PropVariantInit(&value);
    if(SUCCEEDED(store->GetValue(PKEY_AppUserModel_ID,&value))&&value.vt==VT_LPWSTR)windowIdentity=QString::fromWCharArray(value.pwszVal)=="cn.ainfinity.DeeraftApp";PropVariantClear(&value);
    if(SUCCEEDED(store->GetValue(PKEY_AppUserModel_RelaunchIconResource,&value))&&value.vt==VT_LPWSTR)taskbarIcon=QString::fromWCharArray(value.pwszVal).endsWith("DeeraftApp.ico,0");PropVariantClear(&value);store->Release();
   }
   (*report)["taskbarWindowIdentity"]=windowIdentity;(*report)["taskbarIconResource"]=taskbarIcon;
#endif
   QMetaObject::invokeMethod(root,"closeSettings");root->setProperty("page",0);
   QVariantList activity;for(int i=0;i<5;++i)activity.append(QVariantMap{{"player","Player"+QString::number(i)},{"instance","26.3"}});root->setProperty("activity",activity);
   bridge->setColorTheme("lake");elapsed->restart();*phase=9;
  }else if(*phase==9&&elapsed->elapsed()>350){
   auto activity=root->findChild<QObject*>("playerActivityRows");(*report)["activityCappedAtTwo"]=activity&&activity->property("count").toInt()==2;
   QSettings saved(APPLICATION->dataRoot()+"/desktop.ini",QSettings::IniFormat);(*report)["themeSaved"]=saved.value("colorTheme").toString()=="lake";
   (*report)["themeApplied"]=root->property("themeSeed").value<QColor>()==QColor("#4d6e87");
   bridge->setColorTheme("invalid");(*report)["invalidThemeRejected"]=bridge->colorTheme()=="lake";capture("nature-lake-dark");
   bridge->setTheme("light");QMetaObject::invokeMethod(root,"showSettings");
   if(auto scroll=find("settingsScroll"))if(auto flick=scroll->property("contentItem").value<QQuickItem*>())flick->setProperty("contentY",0.);
   elapsed->restart();*phase=10;
  }else if(*phase==10&&elapsed->elapsed()>300){
   bool swatches=true;QSet<QRgb> fills;
   for(const auto& id:{"forest","moss","lake","clay","heather"}){auto button=find((QString("natureTheme_")+id).toUtf8().constData());swatches&=button&&button->property("text").toString().isEmpty();if(button)if(auto state=button->property("mdState").value<QObject*>())fills.insert(state->property("backgroundColor").value<QColor>().rgb());}
   (*report)["connectedColorSwatches"]=find("colorThemeGroup")&&swatches&&fills.size()==5;
   capture("nature-settings-light");QMetaObject::invokeMethod(root,"closeSettings");
   auto chrome=quick->rootContext()->contextProperty("windowChrome").value<QObject*>();
   QMetaObject::invokeMethod(chrome,"toggleMaximize");(*report)["maximizeWorks"]=chrome->property("maximized").toBool();QMetaObject::invokeMethod(chrome,"toggleMaximize");(*report)["restoreWorks"]=!chrome->property("maximized").toBool();
   chrome->setProperty("activeJobs",1);QMetaObject::invokeMethod(chrome,"requestClose");elapsed->restart();*phase=11;
  }else if(*phase==11&&elapsed->elapsed()>250){
   auto dialog=root->findChild<QObject*>("closeConfirmation");(*report)["activeCloseRequiresConfirmation"]=dialog&&dialog->property("visible").toBool();capture("close-confirmation");if(dialog)QMetaObject::invokeMethod(dialog,"close");
   bool ok=true;for(auto value:std::as_const(*report))ok&=value.toBool();(*report)["success"]=ok;
   QSaveFile file(output+"/feedback-checks.json");if(file.open(QIODevice::WriteOnly)){file.write(QJsonDocument(*report).toJson());file.commit();}timer->stop();qApp->exit(ok?0:1);
  }
 });timer->start();return true;
}
