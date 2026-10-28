#pragma once
// Isolated native interaction regression. Enabled only by the explicit smoke flag.
#include <QJSValue>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QTcpServer>
#include <QTcpSocket>
inline bool startPolishProbe(QQuickView* quick, DesktopWindow* host, DesktopBridge* bridge,
                            Deeraft::ExternalGameCatalog* catalog, QObject* owner, const QString& output) {
    if (qEnvironmentVariable("DEERAFT_POLISH_PROBE")!="1") return false;
    const auto report=std::make_shared<QJsonObject>();
    const auto root=quick->rootObject();
    auto named=[](QQuickItem* scope,const char* name){QList<QQuickItem*> result;std::function<void(QQuickItem*)> visit=[&](QQuickItem* node){if(node->objectName()==QString::fromUtf8(name))result.append(node);for(auto child:node->childItems())visit(child);};visit(scope);return result;};
    auto find=[root,quick,named](const char* name){const auto matches=named(quick->contentItem(),name);return matches.isEmpty()?root->findChild<QQuickItem*>(QString::fromUtf8(name)):matches.first();};
    auto capture=[quick,output](const QString& name){quick->grabWindow().save(output+"/"+name+".png");};
    auto click=[quick](QQuickItem* item, bool release=true){if(!item)return;const auto point=item->mapToItem(quick->contentItem(),QPointF(item->width()/2,item->height()/2));QMouseEvent press(QEvent::MouseButtonPress,point,quick->mapToGlobal(point.toPoint()),Qt::LeftButton,Qt::LeftButton,Qt::NoModifier);QApplication::sendEvent(quick,&press);if(release){QMouseEvent up(QEvent::MouseButtonRelease,point,quick->mapToGlobal(point.toPoint()),Qt::LeftButton,Qt::NoButton,Qt::NoModifier);QApplication::sendEvent(quick,&up);}};
    auto move=[quick](QQuickItem* item){if(!item)return;const auto point=item->mapToItem(quick->contentItem(),QPointF(item->width()/2,item->height()/2));QMouseEvent event(QEvent::MouseMove,point,quick->mapToGlobal(point.toPoint()),Qt::NoButton,Qt::NoButton,Qt::NoModifier);QApplication::sendEvent(quick,&event);};
    // Geometry evidence is static: popup animations cannot be judged in an unexposed window.
    auto staticPopup=[](QObject* popup){if(!popup)return;for(const auto name:{"enter","exit"})if(auto transition=popup->property(name).value<QObject*>())transition->setProperty("enabled",false);popup->setProperty("opacity",1.);popup->setProperty("scale",1.);};
    auto put=[](const QString& path,const QByteArray& bytes){QDir().mkpath(QFileInfo(path).absolutePath());QFile file(path);if(file.open(QIODevice::WriteOnly))file.write(bytes);};
    const auto games=output+"/fixtures/.minecraft";
    for(int i=0;i<24;i++){
        const QString version=QString("1.16-%1").arg(i,2,10,QChar('0')),path=games+"/versions/"+version;
        put(path+"/"+version+".json",R"({"id":"test","clientVersion":"1.16.1","patches":[{"id":"game","version":"1.16.1"},{"id":"fabric","version":"0.16.14"}]})");
        put(path+"/hmclversion.cfg",R"({"usesGlobal":false,"gameDirType":1})");
        if(i==0){for(int j=0;j<80;j++)put(path+QString("/mods/mod-%1.jar").arg(j,2,10,QChar('0')),"fixture");for(int j=0;j<4;j++){QDir().mkpath(path+"/screenshots");QFile::copy(":/deeraft/images/village.png",path+QString("/screenshots/test-%1.png").arg(j));}}
    }
    const auto id="external:"+catalog->addRoot(games)+":1.16-00";
    root->setProperty("visualInstances",QVariant::fromValue(QJSValue(QJSValue::NullValue)));
    const int requestedWidth=qEnvironmentVariableIntValue("DEERAFT_POLISH_WIDTH");
    bridge->setTheme("light");host->resize(requestedWidth>0?requestedWidth:1100,680);host->activate();
    // Capture actual native frames at each observation; animation clocks keep wall time.
    const auto page=find("launcherPage");page->setProperty("selectedId",id);
    const auto reloads=std::make_shared<int>(0);
    QObject::connect(bridge,&DesktopBridge::resourcesLoaded,owner,[reloads](const QString&,const QVariantMap&){++*reloads;});
    const auto saved=std::make_shared<QJsonObject>();
    const auto liveRow=std::make_shared<QPointer<QQuickItem>>();
    const auto toggle=std::make_shared<QPointer<QQuickItem>>();
    const auto job=new NetJob("测试资源下载",APPLICATION->network());job->setParent(owner);
    // A local HTTP peer accepts the socket without completing its response.
    auto peer=new QTcpServer(owner);peer->listen(QHostAddress::LocalHost,0);
    QObject::connect(peer,&QTcpServer::newConnection,owner,[peer]{while(peer->hasPendingConnections()){auto socket=peer->nextPendingConnection();QObject::connect(socket,&QTcpSocket::disconnected,socket,&QObject::deleteLater);}});
    auto [download,bytes]=Net::ApiDownload::makeByteArray(QUrl(QString("http://127.0.0.1:%1/polish-cancel").arg(peer->serverPort())));job->addNetAction(download);
    auto pulse=new QTimer(job);pulse->setInterval(40);auto ticks=std::make_shared<int>(0);QObject::connect(pulse,&QTimer::timeout,job,[job,ticks]{if(job->isRunning())job->setStatus(QString("等待服务器响应 · %1").arg(++*ticks));});
    QTimer::singleShot(1000,owner,[=]{quick->grabWindow();
        if(auto list=find("instanceList")){QMetaObject::invokeMethod(list,"positionViewAtBeginning");(*report)["libraryCount"]=list->property("count").toInt();(*report)["libraryViewport"]=list->height();}
        for(auto row:named(root,"instanceRow"))if(row->isVisible())move(row);
        move(find("instanceMenuButton"));bool clean=true;
        for(auto row:named(root,"instanceRow"))if(!row->property("selected").toBool())if(auto state=row->property("mdState").value<QObject*>())clean&=state->property("backgroundColor").value<QColor>().alpha()==0;
        (*report)["rapidHoverClearsRows"]=clean;
        capture("small-library");page->setProperty("detailTab",1);
        if(auto cover=find("instanceCover"))for(auto child:cover->childItems())if(child->property("source").isValid()){(*saved)["cover"]=child->property("source").toUrl().toString();break;}
    });
    QTimer::singleShot(1500,owner,[=]{quick->grabWindow();
        (*saved)["reloads"]=*reloads;
        if(auto scroll=find("instanceDetailScroll")){if(auto flick=scroll->property("contentItem").value<QQuickItem*>())flick->setProperty("contentY",std::max(0.,flick->property("contentHeight").toDouble()-flick->height()));}
        if(auto list=find("modList"))list->setProperty("contentY",25*56.);
    });
    QTimer::singleShot(1900,owner,[=]{quick->grabWindow();
        auto list=find("modList");if(!list)return;
        (*saved)["modY"]=list->property("contentY").toDouble();
        const auto rows=named(list,"modRow");
        for(auto row:rows){const auto p=row->mapToItem(list,QPointF());if(p.y()>=0&&p.y()+row->height()<list->height()){*liveRow=row;const auto switches=named(row,"modToggle");if(!switches.isEmpty())*toggle=switches.first();break;}}
        if(*toggle){(*saved)["checked"]=(*toggle)->property("checked").toBool();click(*toggle);}
    });
    QTimer::singleShot(2300,owner,[=]{
        (*report)["modDelegatePreserved"]=bool(*liveRow)&&bool(*toggle);
        (*report)["modSwitchChanged"]=bool(*toggle)&&(*toggle)->property("checked").toBool()!=saved->value("checked").toBool();
        (*report)["modScrollPreserved"]=find("modList")&&std::abs(find("modList")->property("contentY").toDouble()-saved->value("modY").toDouble())<1;
        (*report)["modDidNotReload"]=*reloads==saved->value("reloads").toInt();capture("mods");
        if(*toggle)click(*toggle);
        page->setProperty("modQuery","mod-25");(*report)["modSearchFilters"]=find("modList")&&find("modList")->property("count").toInt()==1;page->setProperty("modQuery","");
        page->setProperty("detailTab",3);
    });
    QTimer::singleShot(2900,owner,[=]{
        auto carousel=find("screenshotCarousel");(*report)["carouselVisible"]=carousel&&carousel->isVisible();capture("screenshots");
        if(carousel)click(carousel->property("nextControl").value<QQuickItem*>());
        if(auto list=find("instanceList"))list->setProperty("contentY",300);
    });
    QTimer::singleShot(3400,owner,[=]{
        if(auto carousel=find("screenshotCarousel"))(*report)["carouselNavigates"]=carousel->property("currentIndex").toInt()>0;
        page->setProperty("detailTab",0);
        (*report)["tabDidNotReload"]=*reloads==saved->value("reloads").toInt();
        if(auto cover=find("instanceCover"))for(auto child:cover->childItems())if(child->property("source").isValid()){(*report)["coverPreserved"]=child->property("source").toUrl().toString()==saved->value("cover").toString();break;}
        auto search=find("instanceSearch"),list=find("instanceList");(*report)["headerScrollsAway"]=search&&list&&search->mapToItem(list,QPointF()).y()+search->height()<0;
        capture("library-scrolled");put(games+"/versions/1.16-00/mods/downloaded.jar","fixture");QMetaObject::invokeMethod(page,"reloadFiles");root->setProperty("page",0);
    });
    QTimer::singleShot(4000,owner,[=]{quick->grabWindow();
        (*report)["externalInventoryRefresh"]=find("modList")&&find("modList")->property("count").toInt()==81;
        (*report)["nativeExposed"]=quick->isExposed();(*report)["nativeVisible"]=quick->isVisible();(*report)["hostVisible"]=host->isVisible();
        if(auto scroll=find("communityPage")){(*report)["communityType"]=scroll->metaObject()->className();(*report)["communityHeight"]=scroll->height();(*report)["communityParentHeight"]=scroll->parentItem()->height();if(auto c=scroll->property("contentItem").value<QObject*>())(*report)["communityContentType"]=c->metaObject()->className();}
        if(auto scroll=find("communityPage")){auto flick=scroll->property("contentItem").value<QQuickItem*>();if(flick){(*report)["communityContentHeight"]=scroll->property("contentHeight").toDouble();(*report)["flickContentHeight"]=flick->property("contentHeight").toDouble();(*report)["communityViewportHeight"]=flick->height();(*report)["communityScrollable"]=flick->property("contentHeight").toDouble()>flick->height();const auto pos=scroll->mapToItem(quick->contentItem(),QPointF(scroll->width()/2,scroll->height()/2));QWheelEvent wheel(pos,quick->mapToGlobal(pos.toPoint()),QPoint(),QPoint(0,-1200),Qt::NoButton,Qt::NoModifier,Qt::NoScrollPhase,false);QApplication::sendEvent(quick,&wheel);}}
    });
    QTimer::singleShot(4600,owner,[=]{
        if(auto scroll=find("communityPage"))if(auto flick=scroll->property("contentItem").value<QQuickItem*>()){(*report)["communityWheelMoved"]=flick->property("contentY").toDouble()>0;(*report)["communityNoOverscroll"]=flick->property("contentY").toDouble()<=std::max(0.,flick->property("contentHeight").toDouble()-flick->height())+1;}
        capture("community-bottom");
        auto visual=root->property("allInstances").value<QJSValue>().toVariant().toList();
        if(!visual.isEmpty()){auto instance=visual[0].toMap();instance["running"]=true;visual[0]=instance;root->setProperty("visualInstances",visual);}
        job->start();pulse->start();
        auto drawer=root->findChild<QObject*>("downloadTasks");
        QMetaObject::invokeMethod(drawer,"open");
        auto phase=std::make_shared<int>(0);auto elapsed=std::make_shared<QElapsedTimer>();
        auto cancel=std::make_shared<QPointer<QQuickItem>>();
        auto watch=new QTimer(owner);watch->setInterval(16);
        QObject::connect(watch,&QTimer::timeout,owner,[=]{
            // Offscreen sessions need explicit frames to complete popup delegate layout.
            if((*phase>=3&&*phase<=5)||*phase>=9)quick->grabWindow();
            const auto position=drawer->property("position").toDouble();
            if(*phase==0){
                if(position>.01&&position<.99&&!report->contains("drawerIntermediatePosition")){(*report)["drawerIntermediatePosition"]=position;capture("download-enter");}
                if(position<.999)return;
                capture("downloads");*cancel=find("cancelDownload");
                (*report)["taskCenterTitle"]=find("taskCenterTitle")&&find("taskCenterTitle")->property("text").toString()==QStringLiteral("任务中心");
                (*report)["runningInstanceInCenter"]=find("runningInstanceTask")&&find("runningInstanceTask")->isVisible();
                (*report)["requestIndicatorIndeterminate"]=find("taskProgress")&&find("taskProgress")->property("indeterminate").toBool();
                (*report)["cancelButtonFound"]=bool(*cancel);
                if(*cancel)click(*cancel,false);
                elapsed->start();*phase=1;
            }else if(*phase==1&&elapsed->elapsed()>=180){
                if(auto progress=find("runningTaskProgress")){(*report)["runningIndicatorIndeterminate"]=progress->property("indeterminate").toBool();(*report)["runningIndicatorState"]=progress->property("animationState").toInt();(*report)["runningIndicatorProgress"]=progress->property("progress").toDouble();}capture("downloads-running");
                (*report)["cancelButtonPreserved"]=bool(*cancel)&&find("cancelDownload")==cancel->data();
                if(*cancel){const auto point=(*cancel)->mapToItem(quick->contentItem(),QPointF((*cancel)->width()/2,(*cancel)->height()/2));QMouseEvent up(QEvent::MouseButtonRelease,point,quick->mapToGlobal(point.toPoint()),Qt::LeftButton,Qt::NoButton,Qt::NoModifier);QApplication::sendEvent(quick,&up);}
                QMetaObject::invokeMethod(drawer,"close");*phase=2;
            }else if(*phase==2&&!drawer->property("visible").toBool()){
                (*report)["downloadCancelled"]=job->getState()==Task::State::AbortedByUser;
                staticPopup(root->findChild<QObject*>("associationDialog"));if(auto choice=find("associationChoice"))staticPopup(choice->property("popup").value<QObject*>());QMetaObject::invokeMethod(root,"associate",Q_ARG(QVariant,"probe"),Q_ARG(QVariant,"example.org"));elapsed->start();*phase=3;
            }else if(*phase==3&&elapsed->elapsed()>=300){
                if(auto choice=find("associationChoice"))if(auto popup=choice->property("popup").value<QObject*>()){QMetaObject::invokeMethod(popup,"open");QMetaObject::invokeMethod(popup,"completeEnter");quick->grabWindow();if(auto list=popup->property("contentItem").value<QQuickItem*>()){list->setProperty("contentY",120);move(list);(*saved)["menuY"]=list->property("contentY").toDouble();}}
                elapsed->restart();*phase=4;
            }else if(*phase==4&&elapsed->elapsed()>=150){
                QJsonArray geometries;bool fullWidth=true;for(auto option:named(quick->contentItem(),"dropdownOption")){if(!option->isVisible())continue;QJsonObject geometry{{"text",option->property("text").toString()},{"width",option->width()},{"height",option->height()}};if(auto bg=option->property("background").value<QQuickItem*>())geometry["backgroundWidth"]=bg->width();if(auto content=option->property("contentItem").value<QQuickItem*>())geometry["contentWidth"]=content->width();fullWidth&=std::abs(option->width()-320)<1;geometries.append(geometry);}(*report)["dropdownGeometry"]=geometries;(*report)["dropdownRowsFillPopup"]=fullWidth&&!geometries.isEmpty();
                if(auto choice=find("associationChoice"))if(auto popup=choice->property("popup").value<QObject*>()){(*report)["dropdownAvailableWidth"]=popup->property("availableWidth").toDouble();if(auto list=popup->property("contentItem").value<QQuickItem*>())(*report)["dropdownListWidth"]=list->width();}
                if(auto choice=find("associationChoice"))if(auto popup=choice->property("popup").value<QObject*>())if(auto list=popup->property("contentItem").value<QQuickItem*>()){(*report)["menuHoverPreservesScroll"]=std::abs(list->property("contentY").toDouble()-saved->value("menuY").toDouble())<1;capture("association-menu");QKeyEvent home(QEvent::KeyPress,Qt::Key_Home,Qt::NoModifier);QApplication::sendEvent(choice,&home);}
                elapsed->restart();*phase=5;
            }else if(*phase==5&&elapsed->elapsed()>=100){
                if(auto choice=find("associationChoice"))if(auto popup=choice->property("popup").value<QObject*>()){if(auto list=popup->property("contentItem").value<QQuickItem*>())(*report)["menuKeyboardRevealsHighlight"]=list->property("contentY").toDouble()<1;QMetaObject::invokeMethod(popup,"dismissImmediately");}if(auto dialog=root->findChild<QObject*>("associationDialog"))QMetaObject::invokeMethod(dialog,"close");
                QMetaObject::invokeMethod(root,"showSettings");elapsed->restart();*phase=6;
            }else if(*phase==6&&elapsed->elapsed()>=400){
                capture("settings-small");if(auto scroll=find("settingsScroll"))if(auto flick=scroll->property("contentItem").value<QQuickItem*>())flick->setProperty("contentY",std::max(0.,flick->property("contentHeight").toDouble()-flick->height()));elapsed->restart();*phase=7;
            }else if(*phase==7&&elapsed->elapsed()>=200){capture("settings-bottom");bridge->setTheme("dark");elapsed->restart();*phase=8;
            }else if(*phase==8&&elapsed->elapsed()>=200){
                capture("settings-dark");if(auto settings=root->findChild<QObject*>("settingsDialog"))QMetaObject::invokeMethod(settings,"close");bridge->setTheme("light");root->setProperty("visualInstances",QVariant::fromValue(QJSValue(QJSValue::NullValue)));root->setProperty("page",1);page->setProperty("detailTab",0);elapsed->restart();*phase=9;
            }else if(*phase==9&&root->property("displayedPage").toInt()==1&&elapsed->elapsed()>=400){
                if(auto settings=root->findChild<QObject*>("settingsDialog");settings&&settings->property("visible").toBool())return;
                if(auto scroll=find("instanceDetailScroll"))if(auto flick=scroll->property("contentItem").value<QQuickItem*>())flick->setProperty("contentY",0);
                if(auto menu=root->findChild<QObject*>("instanceMenu")){staticPopup(menu);QMetaObject::invokeMethod(menu,"showAt",Q_ARG(QVariant,QVariant::fromValue(find("instanceMenuButton"))));}*phase=10;
            }else if(*phase==10){
                auto menu=root->findChild<QObject*>("instanceMenu");if(!menu||!menu->property("visible").toBool()||menu->property("opacity").toDouble()<.999)return;
                QQuickItem* first=nullptr;QMetaObject::invokeMethod(menu,"itemAt",Q_RETURN_ARG(QQuickItem*,first),Q_ARG(int,0));(*report)["instanceMenuVisible"]=true;
                (*report)["menuNoHiddenLeadingRows"]=first&&first->property("text").toString()==QStringLiteral("编辑实例");
                if(first){auto bg=first->property("background").value<QQuickItem*>();(*report)["menuFullWidthBackground"]=bg&&std::abs(bg->width()-first->width())<1;}
                capture("instance-actions");QMetaObject::invokeMethod(menu,"dismissImmediately");watch->stop();QSaveFile file(output+"/polish-checks.json");if(file.open(QIODevice::WriteOnly)){file.write(QJsonDocument(*report).toJson());file.commit();}qApp->quit();
            }
        });watch->start();
    });
    return true;
}
