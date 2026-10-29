import QtQuick
import QtQuick.Window
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
 ListModel {id:modRows;dynamicRoles:true}
 property string modQuery:""
 function rebuildMods(){modRows.clear();for(var i=0;i<files.length;i++)if(!modQuery||files[i].name.toLowerCase().indexOf(modQuery.toLowerCase())>=0)modRows.append(Object.assign({},files[i],{sourceIndex:i}))}
 onFilesChanged:rebuildMods()
 onModQueryChanged:rebuildMods()
 property var worlds: []
 property var shots: []
 property bool loadingFiles: false
 property string logText: ""
 property var groups: {var list=["全部分组"];for(var i=0;i<app.allInstances.length;i++){var row=app.allInstances[i];var group=library.metadata[row.id]?.group || row.group || "未分组";if(list.indexOf(group)<0)list.push(group)}return list}
 property var filtered: {
   var header=list.headerItem;var query=header?header.searchControl.searchText.toLowerCase():"";var source=header?header.sourceControl.currentValue||"all":"all";var group=header?header.groupControl.currentText||"全部分组":"全部分组";
   var values=app.allInstances.filter(function(row){var meta=library.metadata[row.id]||{};return (!query||row.name.toLowerCase().indexOf(query)>=0)&&(source==="all"||row.source===source)&&(group==="全部分组"||(meta.group||row.group||"未分组")===group)&&(filterIndex!==1||meta.favorite)});
   return reverseOrder?values.slice().reverse():values;
 }
 function focusSearch(){list.positionViewAtBeginning();if(list.headerItem)list.headerItem.searchControl.forceActiveFocus()}
 function isRunning(){return !!selected && !!selected.running}
 function launchSelected(){if(!selected)return;if(isRunning()){desktop.action("actionKillInstance",selected.id)}else app.start(selected,"")}
 property var account: desktop.accounts.find(function(a){return a.selected}) || null
 function selectInstance(id){if(selectedId===id)return;selectedId=id;detailTab=0;titleFade.snapTo(library.reducedMotion?1:0);titleFade.targetValue=1}
 MD.SpringMotion {id:titleFade;targetValue:1;enabled:!library.reducedMotion;spec:MD.Token.motion.spring.expressive.fastEffects}
 function reloadFiles(){if(!selected){files=[];worlds=[];shots=[];loadingFiles=false;logText="";return}loadingFiles=true;desktop.loadResources(selected.id);logText=detailTab===4?desktop.readGameLog(selected.id):""}
 function sameResources(previous,next){if(previous.length!==next.length)return false;for(var i=0;i<next.length;i++)for(var key of ["name","enabled","size","updated"])if(String(previous[i][key])!==String(next[i][key]))return false;return true}
 Connections {target:page.Window.window;function onActiveChanged(){if(page.Window.window.active&&page.selected)page.reloadFiles()}}
 property string resourceKey: selected?(selected.id+"|"+selected.path):""
 onResourceKeyChanged:{files=[];worlds=[];shots=[];reloadFiles();desktop.selectInstance(selected?selected.id:"")}
 property int previousTab:0
 onDetailTabChanged:{if(detailTab===4&&selected)logText=desktop.readGameLog(selected.id);tabPosition.snapTo(library.reducedMotion?0:(detailTab>previousTab?24:-24));previousTab=detailTab;tabPosition.targetValue=0}
 MD.SpringMotion {id:tabPosition;spec:MD.Token.motion.spring.expressive.fastSpatial;enabled:!library.reducedMotion}
 Connections {target:desktop;function onChanged(){if(page.selected && page.detailTab===4)page.logText=desktop.readGameLog(page.selected.id)} function onResourcesLoaded(id,resources){if(page.selected&&page.selected.id===id){var mods=resources.mods||[],images=resources.screenshots||[];if(!page.sameResources(page.files,mods))page.files=mods;page.worlds=resources.saves||[];if(!page.sameResources(page.shots,images))page.shots=images;page.loadingFiles=false}}}
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
     Item {Layout.preferredWidth:32;Layout.preferredHeight:32
      readonly property bool searchHidden:!!list.headerItem&&list.contentY>list.originY+80
      AppLabel {visible:!parent.searchHidden;anchors.centerIn:parent;text:app.allInstances.length;color:app.muted;font.pixelSize:13}
      IconButton {visible:parent.searchHidden;anchors.fill:parent;symbol:"search";hint:"搜索实例 · Ctrl K";onClicked:page.focusSearch()}
     }
     IconButton { id: libraryMenuButton; objectName: "libraryMenuButton"; implicitWidth: 32; implicitHeight: 32; symbol: "more_horiz"; hint: "实例管理"; onClicked: libraryMenu.showAt(this) }
    }
    MD.ListView {
     id: list
     objectName: "instanceList"
     headerPositioning: ListView.InlineHeader
     header: ColumnLayout {
      width:list.width-10;spacing:0
      property alias searchControl:search
      property alias sourceControl:sources
      property alias groupControl:groupPicker
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
     AppSelect { id: sources;padding:8;spacing:4; objectName: "sourcePicker"; Layout.fillWidth: true; Layout.preferredWidth: 1; caption: "实例目录"; model: app.sourceChoices; textRole: "name"; valueRole: "id";displayText:app.width<=1050&&currentValue==="all"?"全部":currentText;MD.ToolTip.text:currentText }
     AppSelect { id: groupPicker;padding:8;spacing:4; objectName: "groupPicker"; Layout.fillWidth: true; Layout.preferredWidth: 1; caption: "分组"; model: page.groups;displayText:app.width<=1050&&currentText==="全部分组"?"全部":currentText;MD.ToolTip.text:currentText }
    }
    MD.ButtonGroupContainer {
     Layout.fillWidth: true
     Layout.preferredHeight: 40
     Layout.bottomMargin: 12
     variant: MD.ButtonGroupContainer.Connected
     animateWidth: false
     size: MD.Enum.S
     Repeater {
      model: ["全部", "收藏"]
      MD.ToggleButton {
       required property string modelData
       required property int index
       text: modelData
       implicitWidth: (libraryPane.width-26)/2
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
     }
     Layout.fillWidth: true
     Layout.fillHeight: true
     model: page.filtered
     spacing: 3
     clip: true
     MD.ScrollBarBase.vertical: MD.ScrollBar {}
     currentIndex:page.filtered.findIndex(function(row){return page.selected&&row.id===page.selected.id})
     highlight:null
     delegate: MD.Card {
      id: rowControl
      objectName:"instanceRow"
      required property var modelData
      readonly property bool selected: !!page.selected && page.selected.id===modelData.id
      width: list.width-10
      height: 78
      flat: true
      type: MD.Enum.CardFilled
      mdState.radius: Math.max(4,8+12*selectionMotion.value)
      mdState.backgroundColor: rowControl.selected?selectionColor.color:rowHover.hovered?app.colors.surfaceContainerHigh:"transparent"
      MD.SpringMotion { id: selectionMotion; targetValue: rowControl.mdState.interactions.pressed?2/3:rowControl.selected?1:0; enabled: !library.reducedMotion; spec: MD.Token.motion.spring.expressive.fastSpatial }
      MD.ColorSpringMotion { id: selectionColor; targetColor: rowControl.selected?app.colors.secondaryContainer:rowControl.mdState.interactions.hovered?app.colors.surfaceContainerHigh:"transparent"; enabled: !library.reducedMotion; spec: MD.Token.motion.spring.standard.fastEffects }
      MD.SpringMotion { id: pressMotion; targetValue: rowControl.mdState.interactions.pressed?.985:1; enabled: !library.reducedMotion; spec: MD.Token.motion.spring.expressive.fastSpatial }
      scale: pressMotion.value
      HoverHandler {id:rowHover}
      horizontalPadding: 12
      onClicked: page.selectInstance(modelData.id)
      TapHandler { onDoubleTapped: app.start(rowControl.modelData, "") }
      contentItem: RowLayout {
       spacing: 12
       InstanceBadge {
        Layout.preferredWidth: app.width<=1050?40:48
        Layout.preferredHeight: app.width<=1050?40:48
        name:rowControl.modelData.name;version:rowControl.modelData.version||"";dark:desktop.dark
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
     AppLabel { text: list.headerItem?list.headerItem.sourceControl.currentText||"全部实例目录":"全部实例目录"; color: app.muted; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideMiddle }
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
    objectName:"instanceDetailScroll"
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
        AppLabel { objectName: "instanceTitle";opacity:titleFade.value; text: page.selected ? page.selected.name : "开始游戏"; font.pixelSize: 45; font.weight: 650; lineHeight: 54; font.letterSpacing: -1; color: app.ink; Layout.fillWidth: true; elide: Text.ElideRight }
        AppLabel { text: page.selected ? (page.selected.version||page.selected.description||"")+(page.selected.loader ? " · "+page.selected.loader : " · Vanilla") : "添加实例或添加实例目录"; font.pixelSize: 13; color: app.muted; Layout.fillWidth: true; elide: Text.ElideRight }
       }
       IconButton { symbol: "tune"; hint: "实例设置"; enabled: !!page.selected; onClicked: desktop.action("actionEditInstance",page.selected.id) }
       IconButton {objectName:"instanceMenuButton"; symbol: "more_vert"; hint: "实例操作"; enabled: !!page.selected; onClicked: instanceMenu.showAt(this) }
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
        mdState.backgroundColor: page.isRunning()?app.colors.error:app.accent
        mdState.textColor: page.isRunning()?app.colors.onError:app.colors.onPrimary
        indicatorMdState.backgroundColor: page.isRunning()?app.colors.error:app.accent
        indicatorMdState.textColor: page.isRunning()?app.colors.onError:app.colors.onPrimary
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
         RoundedImage { source: page.account ? page.account.avatar : ""; Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 12; MD.Icon { visible: !page.account; anchors.centerIn: parent; name: "account_circle"; size: 32; color: app.accent } }
         ColumnLayout { Layout.fillWidth: true; spacing: 0; AppLabel { text: page.account ? page.account.name : "选择游戏账号"; color: app.ink; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight } AppLabel { text: page.account ? page.account.type : "Minecraft 账号"; color: app.muted; font.pixelSize: 12 } }
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
       animationsEnabled: !library.reducedMotion
       mode: MD.TabBar.Fixed
       Layout.fillWidth: true
       Layout.preferredHeight: 48
       currentIndex: page.detailTab
       onCurrentIndexChangeRequested: function(index) {page.detailTab=index}
       Repeater { model: ["概览","模组","世界","截图","日志"]; MD.TabButton { required property string modelData; text: modelData; font.pixelSize: 14 } }
      }
      ColumnLayout {id:tabContent;objectName:"tabContent";Layout.fillWidth:true;spacing:0;transform:Translate {id:tabOffset;x:tabPosition.value}
      ColumnLayout {
       visible: page.detailTab===0
       Layout.fillWidth: true
       spacing: 20
       Layout.topMargin: 14
       RowLayout {
        Layout.fillWidth: true
        spacing: 16
        MD.Icon { name: "coffee"; size: 18; color: app.muted }
        AppLabel {text:"Java  "+(page.selected&&page.selected.javaVersion?(String(page.selected.javaVersion).startsWith("1.")?String(page.selected.javaVersion).split(".")[1]:String(page.selected.javaVersion).split(".")[0]):"自动");font.pixelSize:13;color:app.muted}
        MD.Icon { name: "memory"; size: 18; color: app.muted }
        AppLabel { text: page.selected && page.selected.maxMemory ? "内存  "+(page.selected.maxMemory/1024).toFixed(1)+" GB" : "运行设置"; font.pixelSize: 13; color: app.muted }
        MD.Icon { visible: !!page.selected; name: "schedule"; size: 18; color: app.muted }
        AppLabel { visible: !!page.selected; text: "游玩  "+Number(((page.selected||{}).seconds||0)/3600).toFixed(1)+" 小时"; font.pixelSize: 13; color: app.muted }
        Item { Layout.fillWidth: true }
        ActionButton { text: "调整 ↗"; flat: true; enabled: !!page.selected; onClicked: desktop.action("actionEditInstance",page.selected.id) }
       }
       MD.Pane {
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: 28
        backgroundColor: app.raised
        RowLayout {
         anchors.fill: parent; anchors.leftMargin:8; anchors.rightMargin:8; spacing: 4
         Repeater { model: [{name:"模组",tab:1,icon:"extension"},{name:"存档",tab:2,icon:"public"},{name:"截图",tab:3,icon:"photo_library"}]; ActionButton { required property var modelData; text: modelData.name; symbol: modelData.icon; flat: true; mdState.textColor: app.muted; Layout.fillWidth: true; onClicked: page.detailTab=modelData.tab } }
         ActionButton { text: "文件夹"; symbol: "folder_open"; flat: true; mdState.textColor: app.muted; Layout.fillWidth: true; enabled: !!page.selected; onClicked: desktop.openPath(page.selected.path) }
        }
       }
       RowLayout { Layout.fillWidth: true; AppLabel { text: "最近的世界"; font.weight: 600; color: app.ink; Layout.fillWidth: true } ActionButton { text: "查看全部"; flat: true; onClicked: page.detailTab=2 } }
       Repeater { model: page.worlds.slice(0,2); MD.ListItem { required property var modelData; Layout.fillWidth: true; text: modelData.name; supportText: modelData.updated; icon.name: "public"; onClicked: desktop.openPath(modelData.path) } }
       AppLabel { visible: !page.worlds.length; text: page.loadingFiles?"读取中…":"暂无本地存档"; color: app.muted; font.pixelSize: 13 }
      }
      ColumnLayout {
       visible: page.detailTab===1
       Layout.fillWidth: true
       Layout.topMargin: 20
       spacing: 12
       RowLayout { Layout.fillWidth: true; AppLabel {text:(page.modQuery?modRows.count+" / ":"")+page.files.length+" 个模组";color:app.ink}
        MD.SearchBar {Layout.fillWidth:true;Layout.preferredWidth:180;Layout.minimumWidth:100;Layout.preferredHeight:40;placeholderText:"搜索模组";onSearchTextChanged:page.modQuery=searchText}
        ActionButton { text: "添加模组"; symbol: "add"; enabled: !!page.selected; onClicked: desktop.action("instance-page:mods",page.selected.id) } }
       MD.ListView {
        objectName: "modList"; Layout.fillWidth: true; Layout.preferredHeight: Math.min(count*64,Math.max(240,detailScroll.availableHeight-520))
        model: modRows; clip: true; reuseItems: true; cacheBuffer: 128
        delegate: MD.ListItem {
         id:modRow;objectName:"modRow";required property var model;required property int index
         width:ListView.view.width;height:implicitHeight;text:model.name.replace(/\.disabled$/," ").trim();icon.name:"extension"
         trailing:MD.Switch {
          objectName:"modToggle";checked:modRow.model.enabled;enabled:!page.isRunning()
          onCheckedChangeRequested:function(checked){
           var old=modRow.model.name;
           if(!desktop.setModEnabled(page.selected.id,old,checked))return;
           var name=checked?old.replace(/\.disabled$/,""):old+".disabled";
           modRows.setProperty(modRow.index,"name",name);modRows.setProperty(modRow.index,"enabled",checked);
           page.files[modRow.model.sourceIndex]=Object.assign({},page.files[modRow.model.sourceIndex],{name:name,enabled:checked});
          }
         }
        }
        MD.ScrollBarBase.vertical: MD.ScrollBar {}
       }
       AppLabel { visible: !modRows.count; text: page.loadingFiles?"读取中…":page.files.length?"没有匹配的模组":"暂无模组"; color: app.muted }
      }
      ColumnLayout {
       visible: page.detailTab===2; Layout.fillWidth: true; Layout.topMargin: 20; spacing: 12
       MD.ListView {
        objectName: "worldList"; Layout.fillWidth: true; Layout.preferredHeight: Math.min(count*72,Math.max(240,detailScroll.availableHeight-520))
        model: page.detailTab===2?page.worlds:[]; clip: true; reuseItems: true; cacheBuffer: 144
        delegate: MD.ListItem { objectName: "worldRow"; required property var modelData; width: ListView.view.width; height: implicitHeight; text: modelData.name; supportText: modelData.updated; icon.name: "public"; onClicked: desktop.openPath(modelData.path) }
        MD.ScrollBarBase.vertical: MD.ScrollBar {}
       }
       AppLabel { visible: !page.worlds.length; text: page.loadingFiles?"读取中…":"暂无本地存档"; color: app.muted }
      }
      MD.Carousel {
       objectName:"screenshotCarousel";visible:page.detailTab===3;Layout.fillWidth:true;Layout.topMargin:20;Layout.preferredHeight:page.shots.length?290:0
       layout:MD.Enum.CarouselHero;itemExtent:360;minimumViewportHeight:240;contentPadding:8
       model:page.detailTab===3?page.shots.map(function(shot){return {url:shot.url,title:shot.name}}):[]
       showNavigationButtons:true;showPageIndicator:false;reduceMotion:library.reducedMotion
       onClicked:function(index){if(page.shots[index])desktop.openPath(page.shots[index].path)}
      }
      AppLabel { visible: page.detailTab===3&&!page.shots.length; text: page.loadingFiles?"读取中…":"暂无截图"; color: app.muted }
      TextArea { visible: page.detailTab===4; Layout.fillWidth: true; Layout.topMargin: 20; implicitHeight: Math.max(260,contentHeight+24); text: page.logText||"暂无游戏日志"; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; font.family: "Consolas"; font.pixelSize: 12; color: app.ink }
      }
      Item { Layout.fillWidth: true; Layout.minimumHeight: 24; Layout.fillHeight: true }
      RowLayout { Layout.fillWidth: true; spacing: 7; MD.Icon { name: "circle"; size: 8; color: app.accent } AppLabel { text: page.isRunning()?"运行中":"就绪"; color: app.muted; font.pixelSize: 12 } Item { Layout.fillWidth: true } AppLabel {Layout.maximumWidth:detailScroll.availableWidth*.5;elide:Text.ElideMiddle;property string directory:page.selected?(page.selected.sourcePath||page.selected.path):"";text:directory.replace(/\\/g,"/").replace(/\/$/,"").split("/").pop()||"";MD.ToolTip.text:directory;color:app.muted;font.pixelSize:12} }
     }
    }
   }
  }
 }
 AppMenu {
  id: accountMenu
  model: desktop.accounts
  contentDelegate: MD.MenuItem { required property var modelData; text: modelData.name+" · "+modelData.type; selected: modelData.selected; icon.source: modelData.avatar; onTriggered: desktop.selectAccount(modelData.uuid) }
  MD.MenuSeparator {}
  MD.MenuItem { text: "管理账号"; icon.name: "manage_accounts"; onTriggered: app.showSettings() }
 }
 AppMenu {id:libraryMenu
  objectName: "libraryMenu"
  MD.MenuItem {text:"新建实例 / 导入整合包";onTriggered:desktop.action("actionAddInstance")}
  MD.MenuItem {text:"添加实例目录";enabled:!externalGames.scanning;onTriggered:{var path=desktop.chooseDirectory();if(path)externalGames.addRootAsync(path)}}
  MD.MenuItem {text:"还原已删除实例";onTriggered:desktop.action("actionUndoTrashInstance")}
  MD.MenuItem {text:"管理实例目录";onTriggered:rootsDialog.open()}
  MD.MenuItem {text:"启动器设置";onTriggered:desktop.action("actionSettings")}
 }
 function chooseRunDirectory(){if(!selected||!selected.external)return;var directory=desktop.chooseDirectory();if(!directory)return;var options={};for(var i=0;i<externalGames.roots.length;i++)if(externalGames.roots[i].id===selected.rootId)options=externalGames.roots[i].options||{};var dirs=options.versionDirectories||{};dirs[selected.versionId]=directory;externalGames.setRootOptions(selected.rootId,{versionDirectories:dirs})}
 AppMenu {id:instanceMenu
  objectName:"instanceMenu"
  MD.MenuItem {text:"编辑实例";enabled:!!page.selected;onTriggered:desktop.action("actionEditInstance",page.selected.id)}
  MD.MenuItem {text:"更改分组";onTriggered:{if(page.selected.external){externalGroup.text=app.meta(page.selected).group||"";groupDialog.open()}else desktop.action("actionChangeInstGroup",page.selected.id)}}
  MD.MenuItem {text:"重命名";enabled:!!page.selected;onTriggered:desktop.action("actionRenameInstance",page.selected.id)}
  MD.MenuItem {text:"更换图标";enabled:!!page.selected;onTriggered:desktop.action("actionChangeInstIcon",page.selected.id)}
  MD.MenuItem {text:"资源包";enabled:!!page.selected;onTriggered:desktop.action("instance-page:resourcepacks",page.selected.id)}
  MD.MenuItem {text:"光影";enabled:!!page.selected;onTriggered:desktop.action("instance-page:shaderpacks",page.selected.id)}
  MD.MenuItem {text:"创建快捷方式";enabled:!!page.selected;onTriggered:desktop.action("actionCreateInstanceShortcut",page.selected.id)}
  MD.MenuItem {text:"复制实例";enabled:!!page.selected;onTriggered:desktop.action("actionCopyInstance",page.selected.id)}
  MD.MenuItem {text:"导出实例";enabled:!!page.selected;onTriggered:desktop.action("actionExportInstanceZip",page.selected.id)}
  MD.MenuItem {text:"打开文件夹";onTriggered:desktop.openPath(page.selected.path)}
  MD.MenuSeparator {}
  MD.MenuItem {text:"删除实例";enabled:!!page.selected;onTriggered:desktop.action("actionDeleteInstance",page.selected.id)}
 }
 AppMenu {id:launchMenu
  MD.MenuItem {text:"启动游戏";onTriggered:app.start(page.selected,"")}
  MD.MenuItem {text:"离线启动";enabled:!!page.selected;onTriggered:desktop.action("actionLaunchInstanceOffline",page.selected.id)}
  MD.MenuItem {text:"查看日志";onTriggered:page.detailTab=4}
 }
 AppDialog {id:rootsDialog;objectName:"rootsDialog";title:"实例目录";width:Math.min(page.width-40,650);modal:true;standardButtons:Dialog.Close
  ColumnLayout {width:parent.width;spacing:12
   AppLabel { textFormat: Text.PlainText;objectName:"rootsHeading";text:"DeeraftApp";color:app.ink;font.weight:Font.DemiBold}
   Repeater {model:externalGames.roots;RowLayout {required property var modelData;Layout.fillWidth:true;AppLabel { textFormat: Text.PlainText;objectName:"rootDirectoryPath";text:modelData.path;color:app.ink;Layout.fillWidth:true;elide:Text.ElideMiddle}ActionButton {text:"刷新";flat:true;enabled:!externalGames.scanning;onClicked:externalGames.addRootAsync(modelData.path)}ActionButton {text:"移除目录";flat:true;enabled:!app.allInstances.some(function(row){return row.rootId===modelData.id&&row.running});onClicked:externalGames.removeRoot(modelData.id)}}}
   AppLabel {text:externalGames.error;visible:!!text;Layout.fillWidth:true;wrapMode:Text.Wrap;color:app.colors.error}
   ActionButton {text:"添加实例目录";symbol:"add";enabled:!externalGames.scanning;onClicked:{var path=desktop.chooseDirectory();if(path)externalGames.addRootAsync(path)}}
  }
 }
 AppDialog {id:groupDialog;title:"分组";width:400;modal:true;standardButtons:Dialog.Save|Dialog.Cancel;onAccepted:library.setMetadata(page.selected.id,{group:externalGroup.text.trim()});AppTextField {id:externalGroup;width:parent.width;placeholderText:"分组名称"}}
}
