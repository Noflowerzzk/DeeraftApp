#pragma once
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
   bool ok=true;for(auto value:std::as_const(*report))ok&=value.toBool();(*report)["success"]=ok;
   QSaveFile file(output+"/feedback-checks.json");if(file.open(QIODevice::WriteOnly)){file.write(QJsonDocument(*report).toJson());file.commit();}timer->stop();qApp->exit(ok?0:1);
  }
 });timer->start();return true;
}
