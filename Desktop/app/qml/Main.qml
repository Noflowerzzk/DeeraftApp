import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Theme.js" as Theme
Pane {
 id: root
 padding: 0
 property var colors: desktop.dark ? Theme.schemes.dark : Theme.schemes.light
 property color surface: colors.surface
 property color raised: colors.surfaceContainerLow
 property color panel: colors.surfaceContainerLowest
 property color ink: colors.onSurface
 property color muted: colors.onSurfaceVariant
 property color accent: colors.primary
 property int page: 1
 property bool railExpanded: false
 property var navigation: [{id:0,name:"社区",icon:"diversity_3"},{id:1,name:"启动器",icon:"stadia_controller"},{id:2,name:"服务器",icon:"dns"},{id:4,name:"我的",icon:"person"}]
 property string pageTitle: ["社区","启动器","服务器","社区聊天","我的"][page]
 property var allInstances: desktop.instances.concat(library.externalInstances)
 property var activity: communityClient.activity
 property string toastText: ""
 property string seenDesktopError: ""
 property string seenLibraryError: ""
 property string associationKey: ""
 property string associationAddress: ""
 property bool associationPersonal: false
 property string externalLog: ""
 property var sourceChoices: [{id:"all",name:"全部目录"},{id:"native",name:"DeeraftApp"}].concat(externalGames.roots.map(function(r){return {id:r.id,name:r.path}}))
 Material.theme: desktop.dark ? Material.Dark : Material.Light
 Material.primary: accent; Material.accent: accent
 Material.background: surface; Material.foreground: ink
 background: Rectangle { color: root.surface }
 function clean(text) { return String(text || "").replace(/§[0-9a-fk-or]/gi, "") }
 function duration(minutes) { return Number(minutes||0)<60 ? Math.round(Number(minutes||0))+" 分钟" : (Number(minutes)/60).toFixed(1)+" 小时" }
 function showSettings(){ settings.open() }
 function closeSettings(){ settings.close() }
 function notify(text){toastText=text;toastTimer.restart()}
 function entryKey(row){ return row.id || "" }
 function meta(row){ return library.metadata[entryKey(row)] || ({}) }
 function findInstance(key){for(var i=0;i<allInstances.length;i++)if(allInstances[i].id===key)return allInstances[i];return null}
 function linkedName(key){var row=findInstance(library.links[key]||"");return row?row.name:"未关联实例"}
 function serverAddress(key,fallback){return library.addresses[key]||fallback||"mc.ainfinitythecoder.cn"}
 function associate(key,address){associationKey=key;associationPersonal=library.servers.some(function(s){return s.id===key});associationAddress=serverAddress(key,address);associationAddressField.text=associationAddress;associationChoice.currentIndex=Math.max(0,associationChoice.model.findIndex(function(r){return r.id===library.links[key]}));associationDialog.open()}
 function start(row,address){if(!row)return;if(row.running){notify("该实例正在运行");return}if(row.external){externalLog="";desktop.launchExternal(row.rootId,row.versionId,address||"",meta(row).javaPath||"")}else desktop.launchInstance(row.id,address||"")}
 function joinServer(key,address){address=serverAddress(key,address);var row=findInstance(library.links[key]||"");if(!row){associate(key,address);return}launcher.selectInstance(row.id);page=1;start(row,address)}
 Connections {target:externalLauncher
  function onLogLine(line){root.externalLog=(root.externalLog+line+"\n").slice(-262144)}
  function onErrorChanged(){if(externalLauncher.error)root.notify(externalLauncher.error)}
  function onFinished(exitCode,crashed){root.notify(crashed?"游戏异常退出":exitCode?"游戏退出，代码 "+exitCode:"游戏已退出")}
 }
 Connections { target: communityClient; function onActivityReceived(player,instance){root.notify(player+" 启动了 "+instance)}
 function onOperationFailed(operation,message){root.notify(message)}
 function onOperationFinished(operation,result){var labels={start:"服务器已启动",stop:"服务器已停止",backup:"备份已创建",restore:"备份已恢复",update:"服务器已保存",delete:"服务器已删除",upload:"服务器已上传",avatar:"头像已更新",cover:"封面已更新"};if(labels[operation])root.notify(labels[operation])} }
 Connections { target: desktop; function onGameStarted(name,version){communityClient.reportGameStarted(name,version);if(!communityClient.authenticated)root.notify(name+" 已启动") } function onChanged(){if(desktop.error && desktop.error!==root.seenDesktopError)root.notify(desktop.error);root.seenDesktopError=desktop.error} }
 Connections { target: library; function onChanged(){if(library.error && library.error!==root.seenLibraryError)root.notify(library.error);root.seenLibraryError=library.error} }
 Shortcut { sequence: "Ctrl+K"; onActivated: {root.page=1;launcher.focusSearch()} }
 RowLayout {
   anchors.fill: parent; spacing: 0
   Rectangle {
     Layout.fillHeight: true; Layout.preferredWidth: root.railExpanded?220:96; color: root.raised
     Behavior on Layout.preferredWidth { enabled: !library.reducedMotion; NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
     IconButton { x:28;y:16;symbol:root.railExpanded?"menu_open":"menu";hint:"导航";onClicked:root.railExpanded=!root.railExpanded }
     ActionButton { x:20;y:72;width:root.railExpanded?180:56;height:56;symbol:"add";text:root.railExpanded?"添加实例":"";highlighted:true;onClicked:desktop.action("actionAddInstance") }
     Column {
       x:8;y:160;width:parent.width-16;spacing:12
       Repeater { model:root.navigation; delegate:AbstractButton {
         required property var modelData
         width:parent.width;height:72
         onClicked:root.page=modelData.id
         background:Rectangle {radius:28;color:root.railExpanded&&(root.page===modelData.id||(root.page===3&&modelData.id===0))?root.colors.secondaryContainer:"transparent"}
         Rectangle {x:12;y:root.railExpanded?20:8;width:56;height:32;radius:16;color:!root.railExpanded&&(root.page===modelData.id||(root.page===3&&modelData.id===0))?root.colors.secondaryContainer:"transparent";AppIcon {anchors.centerIn:parent;name:modelData.icon;color:root.ink}}
         Label { textFormat: Text.PlainText;x:root.railExpanded?76:0;y:root.railExpanded?26:44;width:80;text:modelData.name;horizontalAlignment:Text.AlignHCenter;color:root.ink;font.pixelSize:13;font.weight:root.page===modelData.id?Font.DemiBold:Font.Normal
           Behavior on x { enabled:!library.reducedMotion;NumberAnimation {duration:350;easing.type:Easing.OutCubic} }
           Behavior on y { enabled:!library.reducedMotion;NumberAnimation {duration:350;easing.type:Easing.OutCubic} }
         }
       }}
     }
     Column { anchors.bottom:parent.bottom;anchors.bottomMargin:20;x:28;spacing:12
       IconButton {symbol:desktop.dark?"light_mode":"dark_mode";hint:"切换主题";onClicked:desktop.theme=desktop.dark?"light":"dark"}
       IconButton {symbol:"settings";hint:"设置";onClicked:root.showSettings()}
     }
   }
   ColumnLayout {
     Layout.fillWidth:true;Layout.fillHeight:true;spacing:0
     RowLayout {
       Layout.fillWidth:true;Layout.preferredHeight:88;Layout.leftMargin:24;Layout.rightMargin:32
       IconButton {visible:root.page===3;symbol:"arrow_back";hint:"返回社区";onClicked:root.page=0}
       Label { textFormat: Text.PlainText;text:root.pageTitle;font.pixelSize:30;font.weight:Font.DemiBold;color:root.ink;Layout.fillWidth:true}
       BusyIndicator {visible:communityClient.busy;running:visible;Layout.preferredWidth:28;Layout.preferredHeight:28}
       IconButton {visible:root.page!==1;symbol:"refresh";hint:"刷新";onClicked:communityClient.refresh()}
       IconButton {symbol:"download";hint:"下载任务";onClicked:tasksDrawer.open()}
       AbstractButton {implicitWidth:42;implicitHeight:42;onClicked:root.page=4
         background:Rectangle {radius:15;color:root.colors.secondaryContainer}
         contentItem:Image {source:communityClient.authenticated?communityClient.imageUrl(communityClient.profile.avatar_url||""):"";fillMode:Image.PreserveAspectFit;asynchronous:true;AppIcon {anchors.centerIn:parent;name:"person";color:root.ink;visible:parent.status!==Image.Ready}}
       }
     }
     StackLayout {id:stack;Layout.fillWidth:true;Layout.fillHeight:true;currentIndex:root.page
       CommunityPage {app:root}
       LauncherPage {id:launcher;app:root}
       ServersPage {app:root}
       ChatPage {app:root}
       ProfilePage {app:root}
       onCurrentIndexChanged: if(!library.reducedMotion)pageFade.restart()
       NumberAnimation {id:pageFade;target:stack;property:"opacity";from:.45;to:1;duration:150}
     }
   }
 }
 SettingsDialog {id:settings;app:root;anchors.centerIn:parent;width:Math.min(root.width-64,680);height:Math.min(root.height-48,760)}
 AppDialog { id:associationDialog; title:"关联实例";modal:true;anchors.centerIn:parent;width:520;standardButtons:Dialog.NoButton
   ColumnLayout {width:parent.width;spacing:20
     Label { textFormat: Text.PlainText;text:"选择启动并加入服务器的实例";color:root.muted}
     TextField {id:associationAddressField;visible:!root.associationPersonal;Layout.fillWidth:true;placeholderText:"服务器地址"}
     AppSelect {id:associationChoice;Layout.fillWidth:true;model:[{id:"",name:"未关联实例"}].concat(root.allInstances);textRole:"name";valueRole:"id";caption:"实例"}
     Label {textFormat:Text.PlainText;text:library.error;visible:!!text;color:root.colors.error;wrapMode:Text.Wrap;Layout.fillWidth:true}
     RowLayout {Layout.fillWidth:true;Item {Layout.fillWidth:true}ActionButton {text:"取消";flat:true;onClicked:associationDialog.close()}ActionButton {text:"保存";highlighted:true;onClicked:{if(library.associate(root.associationKey,associationChoice.currentValue||"",root.associationPersonal?"":associationAddressField.text))associationDialog.close()}}}
   }
 }
 Drawer {id:tasksDrawer;edge:Qt.RightEdge;width:Math.min(root.width-60,480);height:root.height
   background:Rectangle {color:root.raised;radius:28}
   ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:20
     RowLayout {Layout.fillWidth:true;Label { textFormat: Text.PlainText;text:"下载任务";font.pixelSize:24;Layout.fillWidth:true}IconButton {symbol:"close";hint:"关闭";onClicked:tasksDrawer.close()}}
     ProgressBar {visible:communityClient.uploading;value:communityClient.uploadProgress;Layout.fillWidth:true}
     ActionButton {visible:communityClient.uploading;text:"取消上传";onClicked:communityClient.cancelUpload()}
     Label { textFormat: Text.PlainText;visible:desktop.tasks.length===0&&!communityClient.uploading;text:"暂无任务";color:root.muted}
     ListView {Layout.fillWidth:true;Layout.fillHeight:true;model:desktop.tasks;clip:true;spacing:20
       delegate:ColumnLayout {required property var modelData;width:ListView.view.width
         Label { textFormat: Text.PlainText;text:modelData.name||modelData.status||"下载";wrapMode:Text.Wrap;Layout.fillWidth:true}
         Label { textFormat: Text.PlainText;text:modelData.state+(modelData.error?" · "+modelData.error:"");wrapMode:Text.Wrap;Layout.fillWidth:true;color:root.muted}
         ProgressBar {from:0;to:Math.max(1,modelData.total);value:modelData.current;indeterminate:modelData.total<=0&&modelData.state==="进行中";Layout.fillWidth:true}
         ActionButton {text:"取消";visible:modelData.canCancel;onClicked:desktop.cancelTask(modelData.id)}
       }
     }
   }
 }
 Rectangle {visible:root.toastText.length>0;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:28;width:Math.min(root.width-80,Math.max(300,toastLabel.implicitWidth+100));height:56;radius:4;color:root.colors.inverseSurface;z:1000
   RowLayout {anchors.fill:parent;anchors.margins:12;Label { textFormat: Text.PlainText;id:toastLabel;text:root.toastText;color:root.colors.inverseOnSurface;Layout.fillWidth:true;elide:Text.ElideRight}ActionButton {text:"关闭";flat:true;onClicked:root.toastText=""}}
 }
 Timer {id:toastTimer;interval:5000;onTriggered:root.toastText=""}
}
