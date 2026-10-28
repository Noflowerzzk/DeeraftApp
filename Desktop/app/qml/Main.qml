import QtQuick
import Qcm.Material as MD
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme
MD.Pane {
 id: root
 font: desktop.interfaceFont
 padding: 0
 property var colors: desktop.dark ? Theme.schemes.dark : Theme.schemes.light
 property color surface: colors.surface
 property color raised: colors.surfaceContainerLow
 property color panel: colors.surfaceContainerLowest
 property color ink: colors.onSurface
 property color muted: colors.onSurfaceVariant
 property color accent: colors.primary
 property int page: 1
 property int displayedPage: 1
 onPageChanged: if(pageMotion)pageMotion.run(function(){root.displayedPage=root.page})
 ContentTransition { id: pageMotion; objectName: "pageMotion"; target: stack }
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
 property var sourceChoices: [{id:"all",name:"全部目录"},{id:"native",name:"DeeraftApp"}].concat(externalGames.roots.map(function(r){return {id:r.id,name:r.path}}))
 MD.MProp.color: MD.MdColorMgr {
   accentColor: "#216c5e"
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
 Binding { target: MD.Token.color; property: "accentColor"; value: "#216c5e" }
 Binding { target: MD.Token.color; property: "paletteType"; value: MD.Enum.PaletteTonalSpot }
 Binding { target: MD.Token.color; property: "useSysColorSM"; value: false }
 Binding { target: MD.Token.color; property: "useSysAccentColor"; value: false }
 Binding { target: MD.Token.font; property: "default_font"; value: desktop.interfaceFont }
 function clean(text) { return String(text || "").replace(/§[0-9a-fk-or]/gi, "").replace(/[\r\n\t]+/g," ").replace(/ +/g," ").trim() }
 function duration(minutes) { return Number(minutes||0)<60 ? Math.round(Number(minutes||0))+" 分钟" : (Number(minutes)/60).toFixed(1)+" 小时" }
 function showSettings(){ settings.open() }
 function closeSettings(){ settings.close() }
 function notify(text){notifications.show(String(text), 5000)}
 function entryKey(row){ return row.id || "" }
 function meta(row){ return library.metadata[entryKey(row)] || ({}) }
 function findInstance(key){for(var i=0;i<allInstances.length;i++)if(allInstances[i].id===key)return allInstances[i];return null}
 function linkedName(key){var row=findInstance(library.links[key]||"");return row?row.name:"选择实例"}
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
 Connections { target: externalGames; function onImportFailed(path,message){root.notify(message)} function onImportFinished(path,count){root.notify("已读取 "+count+" 个实例")} }
 Shortcut { sequence: "Ctrl+K"; onActivated: {root.page=1;launcher.focusSearch()} }
 ListModel {
   id: destinations
   ListElement { name: "社区"; icon: "diversity_3"; destination: 0 }
   ListElement { name: "启动器"; icon: "stadia_controller"; destination: 1 }
   ListElement { name: "服务器"; icon: "dns"; destination: 2 }
   ListElement { name: "我的"; icon: "person"; destination: 4 }
 }
 RowLayout {
   anchors.fill: parent
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
       MD.BusyIndicator { visible: communityClient.busy||externalGames.scanning; running: visible; Layout.preferredWidth: 28; Layout.preferredHeight: 28 }
       IconButton { symbol: "download"; hint: "下载任务"; onClicked: tasksDrawer.open()
         MD.Badge { visible: desktop.tasks.some(function(t){return t.state==="进行中"}); anchors.right: parent.right; anchors.top: parent.top; text: desktop.tasks.filter(function(t){return t.state==="进行中"}).length }
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
       currentIndex: root.displayedPage
       CommunityPage { app: root }
       LauncherPage { id: launcher; app: root }
       ServersPage { app: root }
       ChatPage { app: root }
       ProfilePage { app: root }
     }
   }
 }
 SettingsDialog {id:settings;app:root;width:Math.min(root.width-64,680);height:Math.min(root.height-48,760)}
 AppDialog { id:associationDialog; title:"关联实例";modal:true;width:520;standardButtons:Dialog.NoButton
   ColumnLayout {width:parent.width;spacing:20
     AppLabel { textFormat: Text.PlainText;text:"选择启动并加入服务器的实例";color:root.muted}
     AppTextField {id:associationAddressField;visible:!root.associationPersonal;Layout.fillWidth:true;placeholderText:"服务器地址"}
     AppSelect {id:associationChoice;Layout.fillWidth:true;model:[{id:"",name:"未选择实例"}].concat(root.instanceChoices);textRole:"name";valueRole:"id";caption:"实例"}
     AppLabel {textFormat:Text.PlainText;text:library.error;visible:!!text;color:root.colors.error;wrapMode:Text.Wrap;Layout.fillWidth:true}
     RowLayout {Layout.fillWidth:true;Item {Layout.fillWidth:true}ActionButton {text:"取消";flat:true;onClicked:associationDialog.close()}ActionButton {text:"保存";highlighted:true;onClicked:{if(library.associate(root.associationKey,associationChoice.currentValue||"",root.associationPersonal?"":associationAddressField.text))associationDialog.close()}}}
   }
 }
 MD.SideSheetDialog {id:tasksDrawer;objectName:"downloadTasks";edge:MD.SideSheetBase.End;sheetWidth:Math.min(root.width-60,440);animationsEnabled:!library.reducedMotion
   ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:20
     RowLayout {Layout.fillWidth:true;AppLabel { textFormat: Text.PlainText;text:"下载任务";font.pixelSize:24;Layout.fillWidth:true}IconButton {symbol:"close";hint:"关闭";onClicked:tasksDrawer.close()}}
     MD.LinearIndicator { completionBehavior: MD.LinearIndicator.Keep; indeterminate: false; strokeWidth: 4; wavy: true; animationsEnabled: !library.reducedMotion; visible:communityClient.uploading;value:communityClient.uploadProgress;Layout.fillWidth:true}
     ActionButton {visible:communityClient.uploading;text:"取消上传";onClicked:communityClient.cancelUpload()}
     AppLabel { textFormat: Text.PlainText;visible:desktop.tasks.length===0&&!communityClient.uploading;text:"暂无任务";color:root.muted}
     ListView {Layout.fillWidth:true;Layout.fillHeight:true;model:desktop.tasks;clip:true;spacing:20
       delegate:ColumnLayout {required property var modelData;width:ListView.view.width
         AppLabel { textFormat: Text.PlainText;text:modelData.name||modelData.status||"下载";wrapMode:Text.Wrap;Layout.fillWidth:true}
         AppLabel { textFormat: Text.PlainText;text:modelData.state+(modelData.error?" · "+modelData.error:"");wrapMode:Text.Wrap;Layout.fillWidth:true;color:root.muted}
         MD.LinearIndicator { completionBehavior: MD.LinearIndicator.Keep; strokeWidth: 4; wavy: true; animationsEnabled: !library.reducedMotion; from:0;to:Math.max(1,modelData.total);value:modelData.current;indeterminate:modelData.total<=0&&modelData.state==="进行中";Layout.fillWidth:true}
         ActionButton {text:"取消";visible:modelData.canCancel;onClicked:desktop.cancelTask(modelData.id)}
       }
     }
   }
 }
 MD.SnakeView {
   id: notifications
   anchors.right: parent.right
   anchors.bottom: parent.bottom
   anchors.margins: 28
   width: Math.min(440, root.width-80)
   height: Math.min(contentHeight+32, root.height/2)
   bottomToTop: true
 }
}
