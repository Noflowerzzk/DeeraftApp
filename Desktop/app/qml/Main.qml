import QtQuick
import Qcm.Material as MD
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme
MD.Pane {
 id: root
 font: desktop.interfaceFont
 padding: 0
 property var natureThemes: [{id:"forest",name:"森林",seed:"#216c5e"},{id:"moss",name:"苔原",seed:"#617345"},{id:"lake",name:"湖泊",seed:"#4d6e87"},{id:"clay",name:"陶土",seed:"#90654e"},{id:"heather",name:"石楠",seed:"#796382"}]
 property color themeSeed: (natureThemes.find(function(t){return t.id===desktop.colorTheme})||natureThemes[0]).seed
 property var colors: Theme.fromManager(appPalette)
 property color surface: colors.surface
 property color raised: colors.surfaceContainerLow
 property color panel: colors.surfaceContainerLowest
 property color ink: colors.onSurface
 property color muted: colors.onSurfaceVariant
 property color accent: colors.primary
 property int page: 1
 property int displayedPage: 1
 onPageChanged: if(pageMotion){pageMotion.direction=page>displayedPage?1:-1;pageMotion.run(function(){root.displayedPage=root.page})}
 ContentTransition { id: pageMotion; objectName: "pageMotion"; target: stack; translateContent:false }
 property alias railExpanded: rail.expanded
 property var navigation: [{id:0,name:"社区",icon:"diversity_3"},{id:1,name:"启动器",icon:"stadia_controller"},{id:2,name:"服务器",icon:"dns"},{id:4,name:"我的",icon:"person"}]
 property string pageTitle: ["社区","启动器","服务器","社区聊天","我的"][displayedPage]
 property var visualInstances: null
 property var directoryStates: desktop.externalStates
 property var allInstances: visualInstances || desktop.instances.concat(library.externalInstances.map(function(row){return Object.assign({},row,root.directoryStates[row.id]||{},library.metadata[row.id]||{})})).filter(function(row){return !row.hidden})
 property var gameAccount: desktop.accounts.find(function(a){return a.selected})||null
 property var instanceChoices: allInstances.map(function(row){return {id:row.id,name:row.name+" · "+(row.sourcePath||row.path)}})
 property var activity: communityClient.activity
 property string toastText: ""
 property string seenDesktopError: ""
 property string seenLibraryError: ""
 property string associationKey: ""
 property string associationAddress: ""
 property bool associationPersonal: false
 property string externalLog: ""
 property bool showCompletedTasks:false
 property var visibleTasks:{
  var rows=desktop.tasks.filter(function(task){return root.showCompletedTasks||task.state==="进行中"}).map(function(task){return Object.assign({canStop:false,canUploadCancel:false,instanceId:"",icon:"download"},task)});
  allInstances.filter(function(instance){return instance.running}).forEach(function(instance){rows.unshift({id:"instance:"+instance.id,name:instance.name,status:"实例运行中",state:"进行中",icon:"stadia_controller",current:0,total:0,error:"",canCancel:false,canStop:true,canUploadCancel:false,instanceId:instance.id})});
  if(externalGames.scanning)rows.unshift({id:"catalog:scan",name:"检查实例目录",icon:"folder_managed",status:"读取实例信息",state:"进行中",current:0,total:0,error:"",canCancel:false,canStop:false,canUploadCancel:false,instanceId:""});
   if(communityClient.busy&&!communityClient.uploading)rows.push({id:"community:request",name:"社区请求",icon:"cloud_sync",status:"运行中",state:"进行中",current:0,total:0,error:"",canCancel:false,canStop:false,canUploadCancel:false,instanceId:""});
  if(communityClient.uploading)rows.unshift({id:"community:upload",name:"上传服务器",icon:"upload",status:"上传中",state:"进行中",current:communityClient.uploadProgress,total:1,error:"",canCancel:false,canStop:false,canUploadCancel:true,instanceId:""});
  if(appUpdater.busy)rows.unshift({id:"app:update",name:"DeeraftApp 更新",icon:"system_update",status:appUpdater.status,state:"进行中",current:appUpdater.progress,total:appUpdater.progress>0?1:0,error:"",canCancel:false,canStop:false,canUploadCancel:false,instanceId:""});
  return rows;
 }
 property int activeTaskCount:visibleTasks.filter(function(task){return task.state==="进行中"}).length
 ListModel {id:taskRows;dynamicRoles:true}
 function syncTasks(){
  var wanted=visibleTasks||[];
  for(var old=taskRows.count-1;old>=0;old--)if(!wanted.some(function(row){return row.id===taskRows.get(old).taskId}))taskRows.remove(old);
  for(var i=0;i<wanted.length;i++){var data=Object.assign({},wanted[i],{taskId:wanted[i].id});var found=-1;for(var j=i;j<taskRows.count;j++)if(taskRows.get(j).taskId===data.taskId){found=j;break}if(found<0)taskRows.insert(i,data);else{if(found!==i)taskRows.move(found,i,1);taskRows.set(i,data)}}
 }
 onVisibleTasksChanged:if(taskRows)syncTasks()
 Component.onCompleted:syncTasks()
 property var sourceChoices: [{id:"all",name:"全部目录"},{id:"native",name:"DeeraftApp"}].concat(externalGames.roots.map(function(r){return {id:r.id,name:r.path}}))
 MD.MProp.color: MD.MdColorMgr {
   id: appPalette
   accentColor: root.themeSeed
   paletteType: MD.Enum.PaletteTonalSpot
   useSysColorSM: false
   useSysAccentColor: false
   mode: desktop.dark ? MD.Enum.Dark : MD.Enum.Light
 }
 MD.MProp.textColor: ink
 MD.MProp.backgroundColor: surface
 MD.MProp.size: MD.ThemeSize { width: root.width; windowClass: MD.Enum.WindowClassLarge }
 backgroundColor: surface
 Binding { target: MD.Token; property: "themeMode"; value: desktop.dark ? MD.Enum.Dark : MD.Enum.Light }
 Binding { target: MD.Token.color; property: "accentColor"; value: root.themeSeed }
 Binding { target: MD.Token.color; property: "paletteType"; value: MD.Enum.PaletteTonalSpot }
 Binding { target: MD.Token.color; property: "useSysColorSM"; value: false }
 Binding { target: MD.Token.color; property: "useSysAccentColor"; value: false }
 Binding { target: MD.Token.font; property: "default_font"; value: desktop.interfaceFont }
 Binding {target:windowChrome;property:"activeJobs";value:root.activeTaskCount}
 Connections {target:windowChrome;function onCloseConfirmationRequested(){closeConfirmation.open()}}
 AppDialog {
   id:closeConfirmation;objectName:"closeConfirmation";title:"关闭 DeeraftApp？";modal:true;width:Math.min(440,root.width-48)
   ColumnLayout {width:parent.width;spacing:20
     AppLabel {Layout.fillWidth:true;color:root.ink;wrapMode:Text.Wrap;text:"还有任务正在运行。确认关闭窗口？"}
     AppLabel {Layout.fillWidth:true;color:root.muted;wrapMode:Text.Wrap;visible:!!text;text:root.visibleTasks.filter(function(t){return t.state==="进行中"}).slice(0,3).map(function(t){return t.name+" · "+t.status}).join("\n")}
     AppLabel {Layout.fillWidth:true;color:root.muted;wrapMode:Text.Wrap;text:"运行中的游戏不会结束；其他任务在退出应用时会中断。"}
     RowLayout {Layout.fillWidth:true;Item {Layout.fillWidth:true}ActionButton {text:"取消";onClicked:closeConfirmation.close()}ActionButton {text:"关闭窗口";onClicked:{closeConfirmation.close();windowChrome.confirmClose()}}}
   }
 }
 function clean(text) { return String(text || "").replace(/§[0-9a-fk-or]/gi, "").replace(/[\r\n\t]+/g," ").replace(/ +/g," ").trim() }
 function duration(minutes) { return Number(minutes||0)<60 ? Math.round(Number(minutes||0))+" 分钟" : (Number(minutes)/60).toFixed(1)+" 小时" }
 function showSettings(){ settings.open() }
 function closeSettings(){ settings.close() }
 function notify(text){notifications.show(String(text), 6000)}
 function entryKey(row){ return row.id || "" }
 function meta(row){ return library.metadata[entryKey(row)] || ({}) }
 function findInstance(key){for(var i=0;i<allInstances.length;i++)if(allInstances[i].id===key)return allInstances[i];return null}
 function linkedName(key){var row=findInstance(library.links[key]||"");return row?row.name:"选择实例"}
 function serverAddress(key,fallback){return library.addresses[key]||fallback||"mc.ainfinitythecoder.cn"}
 function associate(key,address){associationKey=key;associationPersonal=library.servers.some(function(s){return s.id===key});associationAddress=serverAddress(key,address);associationAddressField.text=associationAddress;associationChoice.currentIndex=Math.max(0,associationChoice.model.findIndex(function(r){return r.id===library.links[key]}));associationDialog.open()}
 function start(row,address){if(!row)return;if(row.running){notify("该实例正在运行");return}if(row.external){externalLog="";desktop.launchExternal(row.rootId,row.versionId,address||"",meta(row).javaPath||"")}else desktop.launchInstance(row.id,address||"")}
 function joinServer(key,address){address=serverAddress(key,address);var row=findInstance(library.links[key]||"");if(!row){associate(key,address);return}launcher.selectInstance(row.id);page=1;start(row,address)}
 Connections {target:appUpdater;function onNotice(message){root.notify(message)}}
 Connections {target:externalLauncher
  function onLogLine(line){root.externalLog=(root.externalLog+line+"\n").slice(-262144)}
  function onErrorChanged(){if(externalLauncher.error)root.notify(externalLauncher.error)}
  function onFinished(exitCode,crashed){root.notify(crashed?"游戏异常退出":exitCode?"游戏退出，代码 "+exitCode:"游戏已退出")}
 }
 Connections { target: communityClient; function onActivityReceived(player,instance){root.notify(player+" 启动了 "+instance)}
 function onOperationFailed(operation,message){root.notify(message)}
 function onOperationFinished(operation,result){var labels={start:"服务器已启动",stop:"服务器已停止",backup:"备份已创建",restore:"备份已恢复",update:"服务器已保存",delete:"服务器已删除",upload:"服务器已上传",avatar:"头像已更新",cover:"封面已更新"};if(labels[operation])root.notify(labels[operation])} }
 Connections { target: desktop; function onNotice(message){root.notify(message)} function onTaskCenterRequested(){tasksDrawer.open()} function onGameStarted(name,version){communityClient.reportGameStarted(name,version);if(!communityClient.authenticated)root.notify(name+" 已启动") } function onChanged(){if(desktop.error && desktop.error!==root.seenDesktopError)root.notify(desktop.error);root.seenDesktopError=desktop.error} }
 Connections { target: library; function onChanged(){if(library.error && library.error!==root.seenLibraryError)root.notify(library.error);root.seenLibraryError=library.error} }
 Connections { target: externalGames; function onImportFailed(path,message){root.notify(message)} function onImportFinished(path,count){root.notify("已读取 "+count+" 个实例")} }
 Shortcut { sequence: "Ctrl+K"; onActivated: {root.page=1;launcher.focusSearch()} }
 ListModel {
   id: destinations
   ListElement { name: "社区"; icon: "diversity_3"; destination: 0 }
   ListElement { name: "启动器"; icon: "stadia_controller"; destination: 1 }
   ListElement { name: "服务器"; icon: "dns"; destination: 2 }
   ListElement { name: "我的"; icon: "person"; destination: 4 }
 }
 AppTitleBar {id:titleBar;app:root;anchors.top:parent.top;anchors.left:parent.left;anchors.right:parent.right;height:36}
 RowLayout {
   anchors.top:titleBar.bottom;anchors.bottom:parent.bottom;anchors.left:parent.left;anchors.right:parent.right
   spacing: 0
   MD.NavigationRail {
     id: rail
     objectName: "appNavigation"
     Layout.fillHeight: true
     Layout.preferredWidth: implicitWidth
     collapsedWidth: 96
     expandedWidth: 220
     useEmbed: true
     autoExpand: false
     arrangement: MD.Enum.RailTop
     itemHeight: 72
     itemSpacing: 12
     itemVerticalPadding: 8
     header: Item {
       implicitHeight: 148
       IconButton { x: 28; y: 4; symbol: rail.expanded?"menu_open":"menu"; hint: "展开导航"; onClicked: rail.expanded=!rail.expanded }
       MD.ExtendedFAB { x: 20; y: 60; width: MD.Util.lerp(56,180,rail.expansionProgress); height: 56; text: "添加实例"; icon.name: "add"; flat: true; minimumExpandedWidth: 0; expansionProgress: rail.expansionProgress; labelOpacity: rail.expansionProgress; animationsEnabled: !library.reducedMotion; onClicked: desktop.action("actionAddInstance") }
     }
     model: destinations
     currentIndex: root.page===4 ? 3 : root.page===3 ? 0 : root.page
     onCurrentIndexChangeRequested: function(index) { root.page=destinations.get(index).destination }
     MD.MProp.backgroundColor: root.raised
     background: Rectangle { color: root.raised; implicitWidth: 96 }
     fabAction: MD.Action { text: "添加实例"; icon.name: "add"; onTriggered: desktop.action("actionAddInstance") }
     footer: Item {
       implicitHeight: 142
       IconButton {
         x: 28; y: 10
         symbol: desktop.dark ? "light_mode" : "dark_mode"
         hint: "切换深浅色"
         onClicked: desktop.theme=desktop.dark ? "light" : "dark"
       }
       MD.RailItem {
         y: 60; width: parent.width; height: 64
         text: "设置"; icon.name: "settings"
         expand: rail.useLarge
         expansionProgress: rail.expansionProgress
         animationsEnabled: !library.reducedMotion
         onSelectionRequested: root.showSettings()
       }
     }
   }
   ColumnLayout {
     Layout.fillWidth: true
     Layout.fillHeight: true
     spacing: 0
     RowLayout {
       Layout.fillWidth: true
       Layout.preferredHeight: 88
       Layout.leftMargin: 24
       Layout.rightMargin: 32
       spacing: 16
       IconButton { visible: root.displayedPage===3; symbol: "arrow_back"; hint: "返回社区"; onClicked: root.page=0 }
       AppLabel { text: root.pageTitle; font.pixelSize: 32; lineHeight: 42; font.weight: 600; font.letterSpacing: -.5; color: root.ink; Layout.fillWidth: true }
       MD.BusyIndicator {objectName:"activeTasksLoading";running:root.activeTaskCount>0&&!library.reducedMotion;visible:root.activeTaskCount>0;indicatorSize:32;Layout.preferredWidth:40;Layout.preferredHeight:40;colors:[root.accent];Accessible.name:"任务运行中"}
       IconButton { objectName:"taskCenterButton";symbol: "assignment"; hint: "任务中心"; onClicked: tasksDrawer.open()
         MD.Badge { visible:root.activeTaskCount>0; anchors.right: parent.right; anchors.top: parent.top; text:root.activeTaskCount }
       }
       MD.IconButton {
         implicitWidth: 42; implicitHeight: 42
         icon.name: "person"
         mdState.type: MD.Enum.IBtFilledTonal
         onClicked: root.page=4
         RoundedImage { visible: !!root.gameAccount; anchors.fill: parent; anchors.margins: 3; radius: 12; source: root.gameAccount?root.gameAccount.avatar:"" }
       }
     }
     StackLayout {
       id: stack
       Layout.fillWidth: true
       Layout.fillHeight: true
       Layout.minimumHeight:0
       Layout.minimumWidth:0
       currentIndex: root.displayedPage
       Item {CommunityPage {anchors.fill:parent;app:root}}
       LauncherPage { id: launcher; app: root }
       ServersPage { app: root }
       ChatPage { app: root }
       ProfilePage { app: root }
     }
   }
 }
 SettingsDialog {id:settings;objectName:"settingsDialog";app:root;width:Math.min(root.width-64,680);height:Math.min(root.height-48,760)}
 AppDialog { id:associationDialog; objectName:"associationDialog";title:"关联实例";modal:true;width:520;standardButtons:Dialog.NoButton
   ColumnLayout {width:parent.width;spacing:20
     AppLabel { textFormat: Text.PlainText;text:"选择启动并加入服务器的实例";color:root.muted}
     AppTextField {id:associationAddressField;visible:!root.associationPersonal;Layout.fillWidth:true;placeholderText:"服务器地址"}
     AppSelect {id:associationChoice;objectName:"associationChoice";Layout.fillWidth:true;model:[{id:"",name:"未选择实例"}].concat(root.instanceChoices);textRole:"name";valueRole:"id";caption:"实例"}
     AppLabel {textFormat:Text.PlainText;text:library.error;visible:!!text;color:root.colors.error;wrapMode:Text.Wrap;Layout.fillWidth:true}
     RowLayout {Layout.fillWidth:true;Item {Layout.fillWidth:true}ActionButton {text:"取消";flat:true;onClicked:associationDialog.close()}ActionButton {text:"保存";highlighted:true;onClicked:{if(library.associate(root.associationKey,associationChoice.currentValue||"",root.associationPersonal?"":associationAddressField.text))associationDialog.close()}}}
   }
 }
 MD.SideSheetDialog {id:tasksDrawer;objectName:"downloadTasks";edge:MD.SideSheetBase.End;sheetWidth:Math.min(root.width-60,440);animationsEnabled:!library.reducedMotion
   ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:20
     RowLayout {Layout.fillWidth:true;AppLabel {objectName:"taskCenterTitle";color:root.ink;textFormat: Text.PlainText;text:"任务中心";font.pixelSize:24;Layout.fillWidth:true}IconButton {symbol:"close";hint:"关闭";onClicked:tasksDrawer.close()}}
     ActionButton {text:root.showCompletedTasks?"收起已结束任务":"显示已结束任务";flat:true;visible:desktop.tasks.some(function(task){return task.state!=="进行中"});onClicked:root.showCompletedTasks=!root.showCompletedTasks}
     AppLabel { textFormat: Text.PlainText;visible:root.visibleTasks.length===0;text:"暂无进行中的任务";color:root.muted}
     ListView {Layout.fillWidth:true;Layout.fillHeight:true;model:taskRows;clip:true;spacing:20
       delegate:ColumnLayout {
         objectName:model.canStop?"runningInstanceTask":"centerTaskRow"
         required property var model;readonly property var modelData:model;width:ListView.view.width;spacing:10
         GridLayout {
          Layout.fillWidth:true;columns:3;columnSpacing:12;rowSpacing:4
          MD.Icon {name:modelData.icon||"download";size:24;color:root.accent;Layout.row:0;Layout.column:0;Layout.alignment:Qt.AlignVCenter}
          AppLabel {text:modelData.name||"任务";color:root.ink;font.weight:600;wrapMode:Text.Wrap;Layout.fillWidth:true;Layout.row:0;Layout.column:1;Layout.alignment:Qt.AlignVCenter}
          MD.CircularIndicator {objectName:modelData.canStop?"runningTaskProgress":"taskProgress";completionBehavior:MD.CircularIndicator.Keep;strokeWidth:3;wavy:true;color:root.accent;inactiveColor:root.colors.outlineVariant;animationsEnabled:!library.reducedMotion;from:0;to:Math.max(1,modelData.total);value:modelData.current;indeterminate:modelData.total<=0&&modelData.state==="进行中";visible:modelData.state==="进行中"||modelData.total>0;Layout.row:0;Layout.column:2;Layout.preferredWidth:48;Layout.preferredHeight:48;Accessible.name:modelData.name+" "+modelData.state}
          AppLabel {text:modelData.canStop?"运行中":modelData.state;Layout.fillWidth:true;Layout.row:1;Layout.column:1;color:root.muted;font.pixelSize:13}
          AppLabel {objectName:"taskPercentage";text:Math.min(100,Math.round(100*modelData.current/Math.max(1,modelData.total)))+"%";visible:modelData.total>0;color:root.muted;font.pixelSize:13;Layout.row:1;Layout.column:2;Layout.alignment:Qt.AlignHCenter}
          AppLabel {text:modelData.error||(/https?:\/\//.test(modelData.status||"")?modelData.current>0?"下载中":"正在请求资源":modelData.status||"");visible:!!text&&(modelData.state==="进行中"||!!modelData.error);Layout.row:2;Layout.column:1;Layout.columnSpan:2;Layout.fillWidth:true;maximumLineCount:2;elide:Text.ElideRight;wrapMode:Text.Wrap;color:root.muted;font.pixelSize:13;MD.ToolTip.text:modelData.status||""}
         }
         ActionButton {objectName:modelData.canCancel?"cancelDownload":"";text:"取消";visible:modelData.canCancel;Layout.leftMargin:36;onClicked:desktop.cancelTask(modelData.id)}
         ActionButton {text:"取消上传";visible:modelData.canUploadCancel;Layout.leftMargin:36;onClicked:communityClient.cancelUpload()}
         ActionButton {text:"结束游戏";symbol:"stop";visible:modelData.canStop;Layout.leftMargin:36;mdState.backgroundColor:root.colors.errorContainer;mdState.textColor:root.colors.onErrorContainer;onClicked:desktop.action("actionKillInstance",modelData.instanceId)}
       }
     }
   }
 }
 AppNotifications {
   id: notifications
   anchors.right: parent.right
   anchors.bottom: parent.bottom
   anchors.margins: 28
   width: Math.min(440, root.width-80)
   height: Math.min(contentHeight+32, root.height/2)
   bottomToTop: true
 }
 Repeater {
   model:windowChrome.maximized?[]:[{edges:3,x:0,y:0,w:7,h:7},{edges:6,x:root.width-7,y:0,w:7,h:7},{edges:9,x:0,y:root.height-7,w:7,h:7},{edges:12,x:root.width-7,y:root.height-7,w:7,h:7},{edges:1,x:0,y:7,w:5,h:root.height-14},{edges:4,x:root.width-5,y:7,w:5,h:root.height-14},{edges:2,x:7,y:0,w:root.width-14,h:5},{edges:8,x:7,y:root.height-5,w:root.width-14,h:5}]
   MouseArea {required property var modelData;x:modelData.x;y:modelData.y;width:modelData.w;height:modelData.h;z:1000;cursorShape:modelData.edges===1||modelData.edges===4?Qt.SizeHorCursor:modelData.edges===2||modelData.edges===8?Qt.SizeVerCursor:modelData.edges===3||modelData.edges===12?Qt.SizeFDiagCursor:Qt.SizeBDiagCursor;onPressed:windowChrome.beginResize(modelData.edges)}
 }
}
