import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
 id: page
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
   var query=search.text.toLowerCase();var source=sources.currentValue||"all";var group=groupPicker.currentText||"全部分组";
   var values=app.allInstances.filter(function(row){var meta=library.metadata[row.id]||{};return (!query||row.name.toLowerCase().indexOf(query)>=0)&&(source==="all"||row.source===source)&&(group==="全部分组"||(meta.group||row.group||"未分组")===group)&&(filterIndex!==1||meta.favorite)&&(filterIndex!==2||row.external)});
   return reverseOrder?values.slice().reverse():values;
 }
 function focusSearch(){search.forceActiveFocus()}
 function selectInstance(id){selectedId=id;detailTab=0;reloadFiles()}
 function reloadFiles(){if(!selected||selected.external){files=[];worlds=[];shots=[];logText="";return}files=desktop.resources(selected.id,"mods");worlds=desktop.resources(selected.id,"saves");shots=desktop.resources(selected.id,"screenshots");logText=detailTab===4?desktop.readGameLog(selected.id):""}
 onSelectedChanged:{reloadFiles();desktop.selectInstance(selected&&!selected.external?selected.id:"")}
 onDetailTabChanged:reloadFiles()
 Connections {target:desktop;function onChanged(){if(page.selected && !page.selected.external && page.detailTab===4)page.logText=desktop.readGameLog(page.selected.id)}}
 RowLayout {
  anchors.fill:parent;anchors.leftMargin:8;anchors.rightMargin:32;anchors.bottomMargin:24;spacing:24
  Rectangle {
   Layout.preferredWidth:page.width<1050?240:300;Layout.fillHeight:true;color:app.raised;radius:28
   ColumnLayout {
    anchors.fill:parent;anchors.margins:12;spacing:12
    RowLayout {Layout.fillWidth:true;Layout.margins:8
     Label { textFormat: Text.PlainText;text:"我的实例";font.pixelSize:20;font.weight:Font.DemiBold;Layout.fillWidth:true;color:app.ink}
     Label { textFormat: Text.PlainText;text:app.allInstances.length;color:app.muted;font.pixelSize:12}
     IconButton {id:libraryMenuButton;symbol:"more_horiz";hint:"实例管理";onClicked:libraryMenu.popup()}
    }
    TextField {id:search;Layout.fillWidth:true;implicitHeight:44;placeholderText:"搜索实例";leftPadding:40;rightPadding:12;font.pixelSize:13
     background:Rectangle {radius:22;color:app.colors.surfaceContainerHigh}
     AppIcon {x:12;anchors.verticalCenter:parent.verticalCenter;name:"search";font.pixelSize:20;color:app.muted}
    }
    RowLayout {Layout.fillWidth:true;spacing:8
     AppSelect {id:sources;Layout.fillWidth:true;Layout.preferredWidth:1;caption:"实例目录";model:app.sourceChoices;textRole:"name";valueRole:"id"}
     AppSelect {id:groupPicker;Layout.fillWidth:true;Layout.preferredWidth:1;caption:"分组";model:page.groups}
    }
    RowLayout {Layout.fillWidth:true;spacing:2
     Repeater {model:["全部","收藏","已关联"];delegate:ActionButton {required property string modelData;required property int index;text:modelData;Layout.fillWidth:true;leftPadding:6;rightPadding:6;font.pixelSize:12;highlighted:page.filterIndex===index;onClicked:page.filterIndex=index}}
    }
    RowLayout {Layout.fillWidth:true;Layout.leftMargin:12
     Label { textFormat: Text.PlainText;text:"最近游玩";color:app.muted;font.pixelSize:12;Layout.fillWidth:true}
     IconButton {symbol:"swap_vert";hint:"切换排序";onClicked:page.reverseOrder=!page.reverseOrder}
    }
    ListView {id:list;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:3;model:page.filtered;ScrollBar.vertical:ScrollBar {}
     delegate:ItemDelegate {required property var modelData;width:list.width;height:76;padding:12
      onClicked:page.selectInstance(modelData.id)
      onDoubleClicked:app.start(modelData,"")
      background:Rectangle {radius:20;color:page.selected&&page.selected.id===modelData.id?app.colors.primaryContainer:parent.hovered?app.colors.surfaceContainerHigh:"transparent"}
      contentItem:RowLayout {spacing:12
       Rectangle {Layout.preferredWidth:44;Layout.preferredHeight:44;radius:15;color:app.colors.secondaryContainer
        Image {anchors.fill:parent;anchors.margins:7;source:!modelData.external?"image://instances/"+modelData.icon:"";fillMode:Image.PreserveAspectFit;smooth:false}
        AppIcon {visible:!!modelData.external;anchors.centerIn:parent;name:"folder";color:app.colors.onSecondaryContainer}
       }
       ColumnLayout {Layout.fillWidth:true;spacing:4
        Label { textFormat: Text.PlainText;text:modelData.name;Layout.fillWidth:true;elide:Text.ElideRight;color:app.ink;font.pixelSize:14;font.weight:Font.Medium}
        Label { textFormat: Text.PlainText;text:modelData.version||modelData.description||"Minecraft";Layout.fillWidth:true;elide:Text.ElideRight;color:app.muted;font.pixelSize:12}
       }
       AppIcon {name:page.selected&&page.selected.id===modelData.id?"check_circle":"star";visible:(page.selected&&page.selected.id===modelData.id)||!!app.meta(modelData).favorite;font.pixelSize:18;color:app.accent}
      }
     }
     Label { textFormat: Text.PlainText;visible:page.filtered.length===0;anchors.centerIn:parent;text:app.allInstances.length?"没有匹配的实例":"添加 Minecraft 实例";color:app.muted;font.pixelSize:13}
    }
    RowLayout {Layout.fillWidth:true
     AppIcon {name:"folder_open";color:app.muted;font.pixelSize:20}
     Label { textFormat: Text.PlainText;text:sources.currentText||"全部目录";Layout.fillWidth:true;elide:Text.ElideMiddle;color:app.muted;font.pixelSize:12}
     IconButton {symbol:"open_in_new";hint:"管理实例目录";onClicked:rootsDialog.open()}
    }
   }
  }
  Rectangle {
   Layout.fillWidth:true;Layout.fillHeight:true;radius:32;color:app.panel;clip:true
   ScrollView {id:detailScroll;anchors.fill:parent;contentWidth:availableWidth;clip:true
    ColumnLayout {width:detailScroll.availableWidth;spacing:0
     Item {Layout.fillWidth:true;Layout.preferredHeight:page.width<1050?190:236;Layout.margins:16
      RoundedImage {anchors.fill:parent;source:page.shots.length?page.shots[page.shots.length-1].url:"qrc:/deeraft/images/village.png";radius:24}
      Rectangle {x:16;y:16;radius:18;color:app.surface;width:timeLabel.implicitWidth+28;height:34
       Label { textFormat: Text.PlainText;id:timeLabel;anchors.centerIn:parent;text:page.selected?Number((page.selected.seconds||0)/3600).toFixed(1)+" 小时":"Minecraft";color:app.ink;font.pixelSize:12}
      }
      IconButton {anchors.right:parent.right;anchors.top:parent.top;anchors.margins:16;symbol:page.selected&&app.meta(page.selected).favorite?"star":"star_outline";hint:"收藏实例";ink:app.accent;enabled:!!page.selected;onClicked:library.setMetadata(page.selected.id,{favorite:!app.meta(page.selected).favorite})}
     }
     ColumnLayout {Layout.fillWidth:true;Layout.margins:32;spacing:20
      RowLayout {Layout.fillWidth:true
       ColumnLayout {Layout.fillWidth:true;spacing:8
        Label { textFormat: Text.PlainText;text:page.selected?page.selected.name:"开始游戏";font.pixelSize:page.width<1050?30:42;color:app.ink;elide:Text.ElideRight;Layout.fillWidth:true}
        Label { textFormat: Text.PlainText;text:page.selected?(page.selected.version||page.selected.description||"")+(page.selected.loader?" · "+page.selected.loader:""):"添加实例或关联 PCL / HMCL 目录";font.pixelSize:13;color:app.muted;Layout.fillWidth:true;elide:Text.ElideRight}
       }
       IconButton {symbol:"tune";hint:"实例设置";enabled:!!page.selected;onClicked:page.selected.external?rootsDialog.open():desktop.action("actionEditInstance",page.selected.id)}
       IconButton {symbol:"more_vert";hint:"实例操作";enabled:!!page.selected;onClicked:instanceMenu.popup()}
      }
      RowLayout {Layout.fillWidth:true;spacing:20
       RowLayout {spacing:2
        ActionButton {text:page.selected&&((page.selected.external&&externalLauncher.running&&externalLauncher.versionId===page.selected.versionId&&externalLauncher.rootId===page.selected.rootId)||page.selected.running)?"结束游戏":"启动游戏";symbol:"play_arrow";highlighted:true;splitLeft:true;font.weight:Font.DemiBold;implicitHeight:60;implicitWidth:190;font.pixelSize:18;enabled:!!page.selected && page.selected.valid!==false
         onClicked:{if(page.selected.external&&externalLauncher.running&&externalLauncher.versionId===page.selected.versionId&&externalLauncher.rootId===page.selected.rootId)externalLauncher.stop();else if(page.selected.running)desktop.action("actionKillInstance",page.selected.id);else app.start(page.selected,"")}
        }
        ActionButton {id:launchButton;text:"";symbol:"keyboard_arrow_down";highlighted:true;splitRight:true;implicitHeight:60;implicitWidth:52;enabled:!!page.selected;onClicked:launchMenu.popup()}
       }
       AbstractButton {implicitWidth:Math.min(180,page.width/5);implicitHeight:52;onClicked:app.showSettings()
        contentItem:RowLayout {spacing:8;AppIcon {name:"account_circle";color:app.accent;font.pixelSize:32}ColumnLayout {Layout.fillWidth:true
         Label { textFormat: Text.PlainText;text:{for(var i=0;i<desktop.accounts.length;i++)if(desktop.accounts[i].selected)return desktop.accounts[i].name;return "选择游戏账号"} elide:Text.ElideRight;Layout.fillWidth:true;color:app.ink;font.pixelSize:13}
         Label { textFormat: Text.PlainText;text:"Minecraft 账号";color:app.muted;font.pixelSize:11}
        }}
       }
       Item {Layout.fillWidth:true}
      }
      TabBar {id:tabs;Layout.fillWidth:true;currentIndex:page.detailTab;onCurrentIndexChanged:page.detailTab=currentIndex
       background:Rectangle {color:"transparent";Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:app.colors.outlineVariant}}
       contentItem:ListView {model:tabs.contentModel;currentIndex:tabs.currentIndex;orientation:ListView.Horizontal;boundsBehavior:Flickable.StopAtBounds;highlightMoveDuration:library.reducedMotion?0:220;highlightFollowsCurrentItem:true
         highlight:Item {z:2;Rectangle {anchors.bottom:parent.bottom;anchors.horizontalCenter:parent.horizontalCenter;height:3;width:parent.width*.44;radius:3;color:app.accent}}
       }
       Repeater {model:["概览","模组","世界","截图","日志"];TabButton {required property string modelData;text:modelData;font.pixelSize:13}}
      }
      ColumnLayout {visible:page.detailTab===0;Layout.fillWidth:true;spacing:20
       RowLayout {Layout.fillWidth:true
        AppIcon {name:"memory";color:app.muted;font.pixelSize:18}
        Label { textFormat: Text.PlainText;text:page.selected&&page.selected.maxMemory?"内存 "+(page.selected.maxMemory/1024).toFixed(1)+" GB":"运行设置";color:app.muted;font.pixelSize:13;Layout.fillWidth:true}
        ActionButton {text:"调整";flat:true;enabled:!!page.selected;onClicked:page.selected.external?rootsDialog.open():desktop.action("actionEditInstance",page.selected.id)}
       }
       Rectangle {Layout.fillWidth:true;implicitHeight:56;radius:28;color:app.raised
        RowLayout {anchors.fill:parent;anchors.margins:4;spacing:2
         Repeater {model:[{name:"模组",tab:1,icon:"extension"},{name:"存档",tab:2,icon:"public"},{name:"截图",tab:3,icon:"photo_library"}];ActionButton {required property var modelData;text:modelData.name;symbol:modelData.icon;flat:true;Layout.fillWidth:true;onClicked:page.detailTab=modelData.tab}}
         ActionButton {text:"文件夹";symbol:"folder_open";flat:true;Layout.fillWidth:true;enabled:!!page.selected;onClicked:desktop.openPath(page.selected.path)}
        }
       }
       RowLayout {Layout.fillWidth:true;Label { textFormat: Text.PlainText;text:"最近的世界";font.weight:Font.DemiBold;color:app.ink;Layout.fillWidth:true}ActionButton {text:"查看全部";flat:true;onClicked:page.detailTab=2}}
       Label { textFormat: Text.PlainText;visible:page.worlds.length===0;text:"暂无本地存档";color:app.muted}
       Repeater {model:page.worlds.slice(0,2);RowLayout {required property var modelData;Layout.fillWidth:true;AppIcon {name:"public";color:app.accent}Label { textFormat: Text.PlainText;text:modelData.name;Layout.fillWidth:true;color:app.ink}IconButton {symbol:"folder_open";hint:"打开存档";onClicked:desktop.openPath(modelData.path)}}}
      }
      ColumnLayout {visible:page.detailTab===1;Layout.fillWidth:true;spacing:12
       RowLayout {Layout.fillWidth:true;Label { textFormat: Text.PlainText;text:page.files.length+" 个模组";font.weight:Font.DemiBold;Layout.fillWidth:true;color:app.ink}ActionButton {text:"管理模组";symbol:"add";enabled:!!page.selected&&!page.selected.external;onClicked:desktop.action("instance-page:mods",page.selected.id)}}
       Label { textFormat: Text.PlainText;visible:!!page.selected&&!!page.selected.external;text:"在原目录中管理模组";color:app.muted}
       Repeater {model:page.files;RowLayout {required property var modelData;Layout.fillWidth:true;spacing:12
        AppIcon {name:"extension";color:app.accent}
        Label { textFormat: Text.PlainText;text:modelData.name;Layout.fillWidth:true;elide:Text.ElideRight;color:app.ink;font.pixelSize:13}
        Switch {checked:modelData.enabled;enabled:page.selected&&!page.selected.running;onToggled:{desktop.setModEnabled(page.selected.id,modelData.name,checked);page.reloadFiles()}}
       }}
      }
      ColumnLayout {visible:page.detailTab===2;Layout.fillWidth:true
       Repeater {model:page.worlds;RowLayout {required property var modelData;Layout.fillWidth:true;AppIcon {name:"public";color:app.accent}Label { textFormat: Text.PlainText;text:modelData.name;Layout.fillWidth:true;color:app.ink}Label { textFormat: Text.PlainText;text:modelData.updated;color:app.muted;font.pixelSize:12}IconButton {symbol:"folder_open";hint:"打开存档";onClicked:desktop.openPath(modelData.path)}}}
       Label { textFormat: Text.PlainText;visible:!page.worlds.length;text:"暂无本地存档";color:app.muted}
      }
      Flow {visible:page.detailTab===3;Layout.fillWidth:true;spacing:12
       Repeater {model:page.shots;AbstractButton {required property var modelData;width:220;height:140;onClicked:desktop.openPath(modelData.path);contentItem:Image {source:modelData.url;fillMode:Image.PreserveAspectCrop;asynchronous:true;clip:true}}}
       Label { textFormat: Text.PlainText;visible:!page.shots.length;text:"暂无截图";color:app.muted}
      }
      TextArea {visible:page.detailTab===4;Layout.fillWidth:true;implicitHeight:Math.max(260,contentHeight+24);text:(page.selected&&page.selected.external?(externalLauncher.versionId===page.selected.versionId&&externalLauncher.rootId===page.selected.rootId?app.externalLog:""):page.logText)||"暂无游戏日志";readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap;font.family:"Consolas";font.pixelSize:12;color:app.ink;background:Rectangle {color:app.raised;radius:16}}
      Label { textFormat: Text.PlainText;visible:!!page.selected;text:page.selected?(page.selected.running?"运行中 · ":"")+(page.selected.sourceName||"DeeraftApp"):"";color:app.muted;font.pixelSize:12;Layout.topMargin:12}
     }
    }
   }
  }
 }
 AppMenu {id:libraryMenu
  MenuItem {text:"新建实例 / 导入整合包";onTriggered:desktop.action("actionAddInstance")}
  MenuItem {text:"关联 PCL / HMCL 目录";onTriggered:{var path=desktop.chooseDirectory();if(path)externalGames.addRoot(path)}}
  MenuItem {text:"还原已删除实例";onTriggered:desktop.action("actionUndoTrashInstance")}
  MenuItem {text:"管理实例目录";onTriggered:rootsDialog.open()}
  MenuItem {text:"启动器设置";onTriggered:desktop.action("actionSettings")}
 }
 function chooseRunDirectory(){if(!selected||!selected.external)return;var directory=desktop.chooseDirectory();if(!directory)return;var options={};for(var i=0;i<externalGames.roots.length;i++)if(externalGames.roots[i].id===selected.rootId)options=externalGames.roots[i].options||{};var dirs=options.versionDirectories||{};dirs[selected.versionId]=directory;externalGames.setRootOptions(selected.rootId,{versionDirectories:dirs})}
 AppMenu {id:instanceMenu
  MenuItem {text:"设置 Java";visible:!!page.selected&&!!page.selected.external;onTriggered:{var file=desktop.chooseFile("Java (java.exe javaw.exe)");if(String(file))library.setMetadata(page.selected.id,{javaPath:String(file)})}}
  MenuItem {text:"设置运行目录";visible:!!page.selected&&!!page.selected.external;onTriggered:page.chooseRunDirectory()}
  MenuItem {text:"编辑实例";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionEditInstance",page.selected.id)}
  MenuItem {text:"更改分组";onTriggered:{if(page.selected.external){externalGroup.text=app.meta(page.selected).group||"";groupDialog.open()}else desktop.action("actionChangeInstGroup",page.selected.id)}}
  MenuItem {text:"重命名";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionRenameInstance",page.selected.id)}
  MenuItem {text:"更换图标";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionChangeInstIcon",page.selected.id)}
  MenuItem {text:"资源包";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("instance-page:resourcepacks",page.selected.id)}
  MenuItem {text:"光影";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("instance-page:shaderpacks",page.selected.id)}
  MenuItem {text:"创建快捷方式";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionCreateInstanceShortcut",page.selected.id)}
  MenuItem {text:"复制实例";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionCopyInstance",page.selected.id)}
  MenuItem {text:"导出实例";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionExportInstance",page.selected.id)}
  MenuItem {text:"打开文件夹";onTriggered:desktop.openPath(page.selected.path)}
  MenuSeparator {}
  MenuItem {text:"删除实例";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionDeleteInstance",page.selected.id)}
 }
 AppMenu {id:launchMenu
  MenuItem {text:"启动游戏";onTriggered:app.start(page.selected,"")}
  MenuItem {text:"离线启动";enabled:!!page.selected&&!page.selected.external;onTriggered:desktop.action("actionLaunchInstanceOffline",page.selected.id)}
  MenuItem {text:"查看日志";onTriggered:page.detailTab=4}
 }
 AppDialog {id:rootsDialog;title:"实例目录";anchors.centerIn:parent;width:Math.min(page.width-40,650);modal:true;standardButtons:Dialog.Close
  ColumnLayout {width:parent.width;spacing:12
   Label { textFormat: Text.PlainText;text:"DeeraftApp";font.weight:Font.DemiBold}
   Repeater {model:externalGames.roots;RowLayout {required property var modelData;Layout.fillWidth:true;Label { textFormat: Text.PlainText;text:modelData.path;Layout.fillWidth:true;elide:Text.ElideMiddle}ActionButton {text:"刷新";flat:true;onClicked:externalGames.scanRoot(modelData.id)}ActionButton {text:"移除关联";flat:true;onClicked:externalGames.removeRoot(modelData.id)}}}
   ActionButton {text:"关联目录";symbol:"add";onClicked:{var path=desktop.chooseDirectory();if(path)externalGames.addRoot(path)}}
  }
 }
 AppDialog {id:groupDialog;title:"分组";anchors.centerIn:parent;width:400;modal:true;standardButtons:Dialog.Save|Dialog.Cancel;onAccepted:library.setMetadata(page.selected.id,{group:externalGroup.text.trim()});TextField {id:externalGroup;width:parent.width;placeholderText:"分组名称"}}
}
