import QtQuick
import Qcm.Material as MD
import QtQuick.Controls
import QtQuick.Layouts
Item {
 id: page
 objectName: "launcherPage"
 required property var app
 property string selectedId: ""
 property int filterIndex: 0
 property int detailTab: 0
 property bool reverseOrder: false
 property var selected: app.findInstance(selectedId) || (app.allInstances.length ? app.allInstances[0] : null)
 property var files: []
 property var worlds: []
 property var shots: []
 property string logText: ""
 property var groups: {var list=["全部分组"];for(var i=0;i<app.allInstances.length;i++){var row=app.allInstances[i];var group=library.metadata[row.id]?.group || row.group || "未分组";if(list.indexOf(group)<0)list.push(group)}return list}
 property var filtered: {
   var query=search.searchText.toLowerCase();var source=sources.currentValue||"all";var group=groupPicker.currentText||"全部分组";
   var values=app.allInstances.filter(function(row){var meta=library.metadata[row.id]||{};return (!query||row.name.toLowerCase().indexOf(query)>=0)&&(source==="all"||row.source===source)&&(group==="全部分组"||(meta.group||row.group||"未分组")===group)&&(filterIndex!==1||meta.favorite)&&(filterIndex!==2||row.external)});
   return reverseOrder?values.slice().reverse():values;
 }
 function focusSearch(){search.forceActiveFocus()}
 function isRunning(){return !!selected && (selected.external ? externalLauncher.running && externalLauncher.rootId===selected.rootId && externalLauncher.versionId===selected.versionId : !!selected.running)}
 function launchSelected(){if(!selected||instanceMotion.running)return;if(isRunning()){if(selected.external)externalLauncher.stop();else desktop.action("actionKillInstance",selected.id)}else app.start(selected,"")}
 property var account: desktop.accounts.find(function(a){return a.selected}) || null
 function selectInstance(id){if(selectedId===id&&!instanceMotion.running)return;instanceMotion.run(function(){page.selectedId=id;page.detailTab=0;page.reloadFiles()})}
 ContentTransition { id: instanceMotion; objectName: "instanceMotion"; target: detail }
 function reloadFiles(){if(!selected||selected.external){files=[];worlds=[];shots=[];logText="";return}files=desktop.resources(selected.id,"mods");worlds=desktop.resources(selected.id,"saves");shots=desktop.resources(selected.id,"screenshots");logText=detailTab===4?desktop.readGameLog(selected.id):""}
 onSelectedChanged:{reloadFiles();desktop.selectInstance(selected&&!selected.external?selected.id:"")}
 onDetailTabChanged:reloadFiles()
 Connections {target:desktop;function onChanged(){if(page.selected && !page.selected.external && page.detailTab===4)page.logText=desktop.readGameLog(page.selected.id)}}
 RowLayout {
  anchors.fill: parent
  anchors.leftMargin: 8
  anchors.rightMargin: app.width>=1600 ? 40 : app.width<=1250 ? 24 : 32
  anchors.bottomMargin: 24
  spacing: 24
  MD.Pane {
   id: libraryPane
   objectName: "instanceLibrary"
   Layout.preferredWidth: app.width>=1600 ? 332 : app.width<=1050 ? 230 : app.width<=1250 ? 268 : 300
   Layout.fillHeight: true
   radius: 28
   backgroundColor: app.raised
   ColumnLayout {
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    spacing: 0
    RowLayout {
     Layout.fillWidth: true
     Layout.topMargin: 20
     Layout.bottomMargin: 16
     Layout.leftMargin: 8
     Layout.rightMargin: 8
     spacing: 12
     AppLabel { text: "我的实例"; font.pixelSize: 20; font.weight: 600; Layout.fillWidth: true; color: app.ink }
     AppLabel { text: app.allInstances.length; color: app.muted; font.pixelSize: 13 }
     IconButton { id: libraryMenuButton; objectName: "libraryMenuButton"; implicitWidth: 32; implicitHeight: 32; symbol: "more_horiz"; hint: "实例管理"; onClicked: libraryMenu.showAt(this) }
    }
    MD.SearchBar {
     id: search
     objectName: "instanceSearch"
     Layout.fillWidth: true
     Layout.preferredHeight: 44
     Layout.bottomMargin: 14
     placeholderText: "搜索实例"
     shortcutText: "Ctrl K"
    }
    RowLayout {
     Layout.fillWidth: true
     Layout.bottomMargin: 14
     spacing: 8
     AppSelect { id: sources; objectName: "sourcePicker"; Layout.fillWidth: true; Layout.preferredWidth: 1.15; caption: "实例目录"; model: app.sourceChoices; textRole: "name"; valueRole: "id" }
     AppSelect { id: groupPicker; objectName: "groupPicker"; Layout.fillWidth: true; Layout.preferredWidth: 1; caption: "分组"; model: page.groups }
    }
    MD.ButtonGroupContainer {
     Layout.fillWidth: true
     Layout.preferredHeight: 40
     Layout.bottomMargin: 12
     variant: MD.ButtonGroupContainer.Connected
     animateWidth: false
     size: MD.Enum.S
     Repeater {
      model: ["全部", "收藏", "已关联"]
      MD.ToggleButton {
       required property string modelData
       required property int index
       text: modelData
       implicitWidth: (libraryPane.width-28)/3
       checked: page.filterIndex===index
       icon.name: checked ? "check" : ""
       mdState.type: MD.Enum.BtFilledTonal
       font.pixelSize: 13
       onCheckedChangeRequested: page.filterIndex=index
       animationsEnabled: !library.reducedMotion
      }
     }
    }
    RowLayout {
     Layout.fillWidth: true
     Layout.leftMargin: 10
     Layout.rightMargin: 8
     Layout.bottomMargin: 8
     AppLabel { text: "最近游玩"; color: app.muted; font.pixelSize: 13; Layout.fillWidth: true }
     IconButton { symbol: "swap_vert"; hint: "切换排序方向"; implicitWidth: 32; implicitHeight: 36; onClicked: page.reverseOrder=!page.reverseOrder }
    }
    ListView {
     id: list
     objectName: "instanceList"
     Layout.fillWidth: true
     Layout.fillHeight: true
     model: page.filtered
     spacing: 3
     clip: true
     ScrollBar.vertical: ScrollBar {}
     delegate: MD.Card {
      id: rowControl
      required property var modelData
      readonly property bool selected: !!page.selected && page.selected.id===modelData.id
      width: list.width-10
      height: 78
      flat: true
      type: MD.Enum.CardFilled
      mdState.radius: selected ? 24 : 20
      mdState.backgroundColor: selected ? app.colors.primaryContainer : "transparent"
      horizontalPadding: 12
      onClicked: page.selectInstance(modelData.id)
      TapHandler { onDoubleTapped: app.start(rowControl.modelData, "") }
      contentItem: RowLayout {
       spacing: 12
       MD.Pane {
        Layout.preferredWidth: 48
        Layout.preferredHeight: 48
        radius: rowControl.selected ? 24 : 16
        backgroundColor: app.colors.secondaryContainer
        Image { anchors.fill: parent; anchors.margins: 8; source: !rowControl.modelData.external ? "image://instances/"+rowControl.modelData.icon : ""; fillMode: Image.PreserveAspectFit; smooth: false }
        MD.Icon { visible: !!rowControl.modelData.external; anchors.centerIn: parent; name: "folder"; size: 28; color: app.colors.onSecondaryContainer }
       }
       ColumnLayout {
        Layout.fillWidth: true
        spacing: 3
        AppLabel { text: rowControl.modelData.name; font.pixelSize: 15; font.weight: 500; Layout.fillWidth: true; elide: Text.ElideRight; color: app.ink }
        AppLabel { text: (rowControl.modelData.version||"Minecraft")+(rowControl.modelData.loader ? " · "+rowControl.modelData.loader.split(" ")[0] : " · Vanilla"); font.pixelSize: 13; color: app.muted; Layout.fillWidth: true; elide: Text.ElideRight }
       }
       MD.Icon { name: rowControl.selected ? "check_circle" : "star"; visible: rowControl.selected || !!app.meta(rowControl.modelData).favorite; size: 18; color: app.accent }
      }
     }
     AppLabel { visible: !list.count; anchors.centerIn: parent; text: app.allInstances.length ? "没有匹配的实例" : "添加 Minecraft 实例"; color: app.muted; font.pixelSize: 13 }
    }
    RowLayout {
     Layout.fillWidth: true
     Layout.topMargin: 16
     Layout.bottomMargin: 16
     Layout.leftMargin: 8
     Layout.rightMargin: 8
     spacing: 10
     MD.Icon { name: "folder_open"; size: 20; color: app.muted }
     AppLabel { text: sources.currentText||"全部实例目录"; color: app.muted; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideMiddle }
     IconButton { symbol: "open_in_new"; hint: "管理实例目录"; implicitWidth: 32; implicitHeight: 32; onClicked: rootsDialog.open() }
    }
   }
  }
  MD.Pane {
   id: detail
   objectName: "instanceDetail"
   Layout.fillWidth: true
   Layout.fillHeight: true
   radius: 32
   backgroundColor: app.panel
   ScrollView {
    id: detailScroll
    anchors.fill: parent
    contentWidth: availableWidth
    clip: true
    ColumnLayout {
     width: detailScroll.availableWidth
     height: Math.max(implicitHeight,detailScroll.availableHeight)
     spacing: 0
     Item {
      Layout.fillWidth: true
      objectName: "instanceCover"
      Layout.preferredHeight: app.height<=850 ? 180 : app.width>=1600 ? 276 : app.width<=1050 ? 180 : 200
      Layout.leftMargin: 16
      Layout.rightMargin: 16
      Layout.topMargin: 16
      RoundedImage { anchors.fill: parent; source: page.shots.length ? page.shots[page.shots.length-1].url : "qrc:/deeraft/images/village.png"; corners: MD.Util.corners(24,24,24,48) }
      MD.Pane {
       x: 16; y: 16; radius: 20; backgroundColor: app.surface; width: coverTime.implicitWidth+24; height: 34
       Row { id: coverTime; anchors.centerIn: parent; spacing: 6; MD.Icon { name: "schedule"; size: 18; color: app.ink; anchors.verticalCenter: parent.verticalCenter } AppLabel { text: page.selected ? Number((page.selected.seconds||0)/3600).toFixed(1)+" 小时" : "Minecraft"; font.pixelSize: 13; color: app.ink } }
      }
      MD.IconButton {
       anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16
       icon.name: "star"; icon.fill: !!page.selected && !!app.meta(page.selected).favorite
       mdState.type: MD.Enum.IBtFilledTonal
       enabled: !!page.selected
       onClicked: library.setMetadata(page.selected.id, {favorite: !app.meta(page.selected).favorite})
      }
     }
     ColumnLayout {
      Layout.fillWidth: true
      Layout.leftMargin: app.width>=1600 ? 40 : app.width<=1250 ? 24 : 32
      Layout.rightMargin: app.width>=1600 ? 40 : app.width<=1250 ? 24 : 32
      Layout.topMargin: 24
      Layout.bottomMargin: 14
      Layout.fillHeight: true
      spacing: 0
      RowLayout {
       Layout.fillWidth: true
       spacing: 16
       ColumnLayout {
        Layout.fillWidth: true
        spacing: 7
        AppLabel { objectName: "instanceTitle"; text: page.selected ? page.selected.name : "开始游戏"; font.pixelSize: 45; font.weight: 650; lineHeight: 54; font.letterSpacing: -1; color: app.ink; Layout.fillWidth: true; elide: Text.ElideRight }
        AppLabel { text: page.selected ? (page.selected.version||page.selected.description||"")+(page.selected.loader ? " · "+page.selected.loader : " · Vanilla") : "添加实例或关联 PCL / HMCL 目录"; font.pixelSize: 13; color: app.muted; Layout.fillWidth: true; elide: Text.ElideRight }
       }
       IconButton { symbol: "tune"; hint: "实例设置"; enabled: !!page.selected; onClicked: page.selected.external ? rootsDialog.open() : desktop.action("actionEditInstance",page.selected.id) }
       IconButton { symbol: "more_vert"; hint: "实例操作"; enabled: !!page.selected; onClicked: instanceMenu.showAt(this) }
      }
      RowLayout {
       Layout.fillWidth: true
       Layout.topMargin: 20
       Layout.bottomMargin: 20
       spacing: 24
       MD.SplitButton {
        id: launchButton
        objectName: "launchGame"
        Layout.preferredWidth: 260
        Layout.preferredHeight: 64
        enabled: !!page.selected && page.selected.valid!==false
        text: page.isRunning() ? "结束游戏" : "启动游戏"
        icon.name: page.isRunning() ? "stop" : "play_arrow"
        mdState.type: MD.Enum.BtFilled
        mdState.size: MD.Enum.M
        leadingControl.font.pixelSize: 18
        leadingControl.font.weight: 650
        leadingControl.icon.width: 30
        leadingControl.icon.height: 30
        trailingControl.width: 56
        menu: launchMenu
        onClicked: page.launchSelected()
       }
       MD.Button {
        implicitWidth: Math.min(220,page.width/5)
        implicitHeight: 52
        flat: true
        mdState.type: MD.Enum.BtText
        onClicked: accountMenu.showAt(this)
        contentItem: RowLayout {
         spacing: 10
         RoundedImage { source: page.account ? "https://minotar.net/avatar/"+encodeURIComponent(page.account.name)+"/40" : ""; Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 12; MD.Icon { visible: !page.account; anchors.centerIn: parent; name: "account_circle"; size: 32; color: app.accent } }
         ColumnLayout { Layout.fillWidth: true; spacing: 0; AppLabel { text: page.account ? page.account.name : "选择游戏账号"; color: app.ink; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight } AppLabel { text: page.account ? page.account.type+" 账号" : "Minecraft 账号"; color: app.muted; font.pixelSize: 12 } }
         MD.Icon { name: "unfold_more"; size: 20; color: app.muted }
        }
       }
       Item { Layout.fillWidth: true }
       Column { visible: !!page.selected && !!page.selected.lastPlayed; spacing: 2; AppLabel { text: "上次游玩"; color: app.muted; font.pixelSize: 13 } AppLabel { text: page.selected ? page.selected.lastPlayed||"" : ""; color: app.ink; font.pixelSize: 13 } }
      }
      MD.TabBar {
       id: tabs
       objectName: "detailTabs"
       MD.MProp.backgroundColor: app.panel
       primaryIndicatorFraction: .44
       Layout.fillWidth: true
       Layout.preferredHeight: 48
       currentIndex: page.detailTab
       onCurrentIndexChangeRequested: function(index) {page.detailTab=index}
       Repeater { model: ["概览","模组","世界","截图","日志"]; MD.TabButton { required property string modelData; text: modelData; width: tabs.width/5; font.pixelSize: 14 } }
      }
      ColumnLayout {
       visible: page.detailTab===0
       Layout.fillWidth: true
       spacing: 20
       Layout.topMargin: 2
       RowLayout {
        Layout.fillWidth: true
        spacing: 16
        MD.Icon { name: "memory"; size: 18; color: app.muted }
        AppLabel { text: page.selected && page.selected.maxMemory ? "内存  "+(page.selected.maxMemory/1024).toFixed(1)+" GB" : "运行设置"; font.pixelSize: 13; color: app.muted }
        MD.Icon { visible: !!page.selected; name: "schedule"; size: 18; color: app.muted }
        AppLabel { visible: !!page.selected; text: "游玩  "+Number(((page.selected||{}).seconds||0)/3600).toFixed(1)+" 小时"; font.pixelSize: 13; color: app.muted }
        Item { Layout.fillWidth: true }
        ActionButton { text: "调整 ↗"; flat: true; enabled: !!page.selected; onClicked: page.selected.external ? rootsDialog.open() : desktop.action("actionEditInstance",page.selected.id) }
       }
       MD.Pane {
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: 28
        backgroundColor: app.raised
        RowLayout {
         anchors.fill: parent; spacing: 0
         Repeater { model: [{name:"模组",tab:1,icon:"extension"},{name:"存档",tab:2,icon:"public"},{name:"截图",tab:3,icon:"photo_library"}]; ActionButton { required property var modelData; text: modelData.name; symbol: modelData.icon; flat: true; mdState.textColor: app.muted; Layout.fillWidth: true; onClicked: page.detailTab=modelData.tab } }
         ActionButton { text: "文件夹"; symbol: "folder_open"; flat: true; mdState.textColor: app.muted; Layout.fillWidth: true; enabled: !!page.selected; onClicked: desktop.openPath(page.selected.path) }
        }
       }
       RowLayout { Layout.fillWidth: true; AppLabel { text: "最近的世界"; font.weight: 600; color: app.ink; Layout.fillWidth: true } ActionButton { text: "查看全部"; flat: true; onClicked: page.detailTab=2 } }
       Repeater { model: page.worlds.slice(0,2); MD.ListItem { required property var modelData; Layout.fillWidth: true; text: modelData.name; supportText: modelData.updated; icon.name: "public"; onClicked: desktop.openPath(modelData.path) } }
       AppLabel { visible: !page.worlds.length; text: "暂无本地存档"; color: app.muted; font.pixelSize: 13 }
      }
      ColumnLayout {
       visible: page.detailTab===1
       Layout.fillWidth: true
       Layout.topMargin: 20
       spacing: 12
       RowLayout { Layout.fillWidth: true; AppLabel { text: page.files.length+" 个模组"; Layout.fillWidth: true; color: app.ink } ActionButton { text: "添加模组"; symbol: "add"; enabled: !!page.selected && !page.selected.external; onClicked: desktop.action("instance-page:mods",page.selected.id) } }
       Repeater { model: page.files; MD.ListItem { id: modRow; required property var modelData; Layout.fillWidth: true; text: modelData.name.replace(/\.disabled$/,""); icon.name: "extension"; trailing: MD.Switch { checked: modRow.modelData.enabled; enabled: !page.isRunning(); onCheckedChangeRequested: function(checked) {if(desktop.setModEnabled(page.selected.id,modRow.modelData.name,checked))page.reloadFiles()} } } }
       AppLabel { visible: !page.files.length; text: page.selected && page.selected.external ? "通过文件夹管理外部实例模组" : "暂无模组"; color: app.muted }
      }
      ColumnLayout { visible: page.detailTab===2; Layout.fillWidth: true; Layout.topMargin: 20; spacing: 12; Repeater { model: page.worlds; MD.ListItem { required property var modelData; Layout.fillWidth: true; text: modelData.name; supportText: modelData.updated; icon.name: "public"; onClicked: desktop.openPath(modelData.path) } } AppLabel { visible: !page.worlds.length; text: "暂无本地存档"; color: app.muted } }
      Flow { visible: page.detailTab===3; Layout.fillWidth: true; Layout.topMargin: 20; spacing: 12; Repeater { model: page.shots; MD.Card { required property var modelData; width: 220; height: 140; onClicked: desktop.openPath(modelData.path); contentItem: RoundedImage { source: modelData.url; radius: 16 } } } AppLabel { visible: !page.shots.length; text: "暂无截图"; color: app.muted } }
      TextArea { visible: page.detailTab===4; Layout.fillWidth: true; Layout.topMargin: 20; implicitHeight: Math.max(260,contentHeight+24); text: (page.selected && page.selected.external ? (externalLauncher.versionId===page.selected.versionId && externalLauncher.rootId===page.selected.rootId ? app.externalLog : "") : page.logText)||"暂无游戏日志"; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; font.family: "Consolas"; font.pixelSize: 12; color: app.ink }
      Item { Layout.fillWidth: true; Layout.minimumHeight: 24; Layout.fillHeight: true }
      RowLayout { Layout.fillWidth: true; spacing: 7; MD.Icon { name: "circle"; size: 8; color: app.accent } AppLabel { text: page.isRunning()?"运行中":"就绪"; color: app.muted; font.pixelSize: 12 } Item { Layout.fillWidth: true } AppLabel { text: page.selected&&page.selected.external?page.selected.sourceName||"已关联实例":"本地实例"; color: app.muted; font.pixelSize: 12 } }
     }
    }
   }
  }
 }
 AppMenu {
  id: accountMenu
  model: desktop.accounts
  contentDelegate: MD.MenuItem { required property var modelData; text: modelData.name+" · "+modelData.type; selected: modelData.selected; icon.name: "account_circle"; onTriggered: desktop.selectAccount(modelData.uuid) }
  MD.MenuSeparator {}
  MD.MenuItem { text: "管理账号"; icon.name: "manage_accounts"; onTriggered: app.showSettings() }
 }
 AppMenu {id:libraryMenu
  objectName: "libraryMenu"
  MD.MenuItem {text:"新建实例 / 导入整合包";onTriggered:desktop.action("actionAddInstance")}
  MD.MenuItem {text:"关联 PCL / HMCL 目录";onTriggered:{var path=desktop.chooseDirectory();if(path)externalGames.addRoot(path)}}
  MD.MenuItem {text:"还原已删除实例";onTriggered:desktop.action("actionUndoTrashInstance")}
  MD.MenuItem {text:"管理实例目录";onTriggered:rootsDialog.open()}
  MD.MenuItem {text:"启动器设置";onTriggered:desktop.action("actionSettings")}
 }
 function chooseRunDirectory(){if(!selected||!selected.external)return;var directory=desktop.chooseDirectory();if(!directory)return;var options={};for(var i=0;i<externalGames.roots.length;i++)if(externalGames.roots[i].id===selected.rootId)options=externalGames.roots[i].options||{};var dirs=options.versionDirectories||{};dirs[selected.versionId]=directory;externalGames.setRootOptions(selected.rootId,{versionDirectories:dirs})}
 AppMenu {id:instanceMenu
  MD.MenuItem {text:"设置 Java";visible:!!page.selected&&!!page.selected.external;onTriggered:{var file=desktop.chooseFile("Java (java.exe javaw.exe)");if(String(file))library.setMetadata(page.selected.id,{javaPath:String(file)})}}
  MD.MenuItem {text:"设置运行目录";visible:!!page.selected&&!!page.selected.external;onTriggered:page.chooseRunDirectory()}
  MD.MenuItem {text:"编辑实例";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionEditInstance",page.selected.id)}
  MD.MenuItem {text:"更改分组";onTriggered:{if(page.selected.external){externalGroup.text=app.meta(page.selected).group||"";groupDialog.open()}else desktop.action("actionChangeInstGroup",page.selected.id)}}
  MD.MenuItem {text:"重命名";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionRenameInstance",page.selected.id)}
  MD.MenuItem {text:"更换图标";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionChangeInstIcon",page.selected.id)}
  MD.MenuItem {text:"资源包";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("instance-page:resourcepacks",page.selected.id)}
  MD.MenuItem {text:"光影";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("instance-page:shaderpacks",page.selected.id)}
  MD.MenuItem {text:"创建快捷方式";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionCreateInstanceShortcut",page.selected.id)}
  MD.MenuItem {text:"复制实例";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionCopyInstance",page.selected.id)}
  MD.MenuItem {text:"导出实例";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionExportInstance",page.selected.id)}
  MD.MenuItem {text:"打开文件夹";onTriggered:desktop.openPath(page.selected.path)}
  MD.MenuSeparator {}
  MD.MenuItem {text:"删除实例";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionDeleteInstance",page.selected.id)}
 }
 AppMenu {id:launchMenu
  MD.MenuItem {text:"启动游戏";onTriggered:app.start(page.selected,"")}
  MD.MenuItem {text:"离线启动";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionLaunchInstanceOffline",page.selected.id)}
  MD.MenuItem {text:"查看日志";onTriggered:page.detailTab=4}
 }
 AppDialog {id:rootsDialog;title:"实例目录";width:Math.min(page.width-40,650);modal:true;standardButtons:Dialog.Close
  ColumnLayout {width:parent.width;spacing:12
   AppLabel { textFormat: Text.PlainText;text:"DeeraftApp";font.weight:Font.DemiBold}
   Repeater {model:externalGames.roots;RowLayout {required property var modelData;Layout.fillWidth:true;AppLabel { textFormat: Text.PlainText;text:modelData.path;Layout.fillWidth:true;elide:Text.ElideMiddle}ActionButton {text:"刷新";flat:true;onClicked:externalGames.scanRoot(modelData.id)}ActionButton {text:"移除关联";flat:true;onClicked:externalGames.removeRoot(modelData.id)}}}
   ActionButton {text:"关联目录";symbol:"add";onClicked:{var path=desktop.chooseDirectory();if(path)externalGames.addRoot(path)}}
  }
 }
 AppDialog {id:groupDialog;title:"分组";width:400;modal:true;standardButtons:Dialog.Save|Dialog.Cancel;onAccepted:library.setMetadata(page.selected.id,{group:externalGroup.text.trim()});AppTextField {id:externalGroup;width:parent.width;placeholderText:"分组名称"}}
}
