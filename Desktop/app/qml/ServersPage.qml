import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: page; required property var app; padding: 24
    property string selected: ""
    property string pendingAction: ""
    property bool admin: communityClient.profile.role === "admin"
    function operate(action, name) { selected = name; pendingAction = action; confirm.open() }
    property bool onlyRunning:false
    ScrollView {anchors.fill:parent;contentWidth:availableWidth;clip:true
     ColumnLayout {width:parent.availableWidth;spacing:24
      RowLayout {Layout.fillWidth:true
       ActionButton {text:"全部服务器";highlighted:!page.onlyRunning;onClicked:page.onlyRunning=false}
       ActionButton {text:"运行中";highlighted:page.onlyRunning;onClicked:page.onlyRunning=true}
       Item {Layout.fillWidth:true}
       ActionButton {text:"上传服务器";symbol:"upload";highlighted:true;visible:page.admin;onClicked:upload.open()}
      }
      Flow {id:serverFlow;Layout.fillWidth:true;spacing:24
       Repeater {model:communityClient.servers.filter(function(s){return !page.onlyRunning || s.is_running || s.running || s.status==="running"});Rectangle {
        required property var modelData
        property bool running:!!(modelData.is_running||modelData.running||modelData.status==="running")
        width:serverFlow.width<850?serverFlow.width:(serverFlow.width-24)/2;height:serverBody.implicitHeight+240;radius:28;color:app.panel;clip:true
        RoundedImage {x:12;y:12;width:parent.width-24;height:200;source:modelData.cover_url?communityClient.imageUrl(modelData.cover_url):"qrc:/deeraft/images/village.png";radius:24}
        ColumnLayout {id:serverBody;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.topMargin:232;anchors.leftMargin:24;anchors.rightMargin:24;spacing:12
         RowLayout {Layout.fillWidth:true;Label { textFormat: Text.PlainText;text:modelData.name;Layout.fillWidth:true;font.pixelSize:26;color:app.ink}Label { textFormat: Text.PlainText;text:running?"运行中":"已停止";color:app.accent;font.pixelSize:13}}
         Label { textFormat: Text.PlainText;text:app.clean(modelData.motd||modelData.description||"");color:app.muted;wrapMode:Text.Wrap;Layout.fillWidth:true;font.pixelSize:13}
         RowLayout {Layout.fillWidth:true;ActionButton {text:app.linkedName(modelData.name);symbol:"link";flat:true;onClicked:app.associate(modelData.name,modelData.address||"")}ActionButton {text:"启动实例并加入";symbol:"sports_esports";flat:true;onClicked:app.joinServer(modelData.name,app.serverAddress(modelData.name,modelData.address||""))}}
         Flow {Layout.fillWidth:true;spacing:4
          ActionButton {text:running?"停止":"启动";highlighted:!running;onClicked:page.operate(running?"stop":"start",modelData.name)}
          ActionButton {text:"编辑";visible:page.admin;flat:true;onClicked:{page.selected=modelData.name;motd.text=modelData.motd||"";edit.open()}}
          ActionButton {text:"备份";visible:page.admin;flat:true;onClicked:page.operate("backup",modelData.name)}
          ActionButton {text:"恢复";visible:page.admin;flat:true;onClicked:{page.selected=modelData.name;communityClient.loadBackups(page.selected);backups.open()}}
          ActionButton {text:"控制台";visible:page.admin;flat:true;onClicked:{page.selected=modelData.name;communityClient.watchLogs(page.selected);consoleDialog.open()}}
          ActionButton {text:"删除";visible:page.admin;flat:true;onClicked:page.operate("delete",modelData.name)}
         }
        }
       }}
      }
      Label { textFormat: Text.PlainText;visible:!communityClient.servers.length;text:communityClient.authenticated?"暂无服务器":"登录后查看社区服务器";color:app.muted}
      RowLayout {Layout.fillWidth:true;Label { textFormat: Text.PlainText;text:"第三方服务器";font.pixelSize:22;font.weight:Font.DemiBold;color:app.ink;Layout.fillWidth:true}ActionButton {text:"添加服务器";symbol:"add";onClicked:page.editPersonal(null)}}
      Repeater {model:library.servers;Rectangle {
       required property var modelData
       Layout.fillWidth:true;implicitHeight:140;radius:24;color:app.panel
       RowLayout {anchors.fill:parent;anchors.margins:20;spacing:16
        AppIcon {name:"public";color:app.accent;font.pixelSize:32}
        ColumnLayout {Layout.fillWidth:true;spacing:6
         RowLayout {Label { textFormat: Text.PlainText;text:modelData.name;font.pixelSize:17;color:app.ink}Label { textFormat: Text.PlainText;text:modelData.status.label;color:modelData.status.state==="unavailable"?app.colors.error:app.accent;font.pixelSize:12}}
         Label { textFormat: Text.PlainText;text:modelData.address;color:app.muted;font.pixelSize:12;Layout.fillWidth:true;elide:Text.ElideMiddle}
         Label { textFormat: Text.PlainText;text:(modelData.status.version||"版本 —")+"    "+(modelData.status.online!==undefined?modelData.status.online+" / "+modelData.status.max:"—")+" 在线"+(modelData.status.latency!==undefined?"    "+modelData.status.latency+" ms":"");color:app.muted;font.pixelSize:12;Layout.fillWidth:true;elide:Text.ElideRight}
         ActionButton {text:app.linkedName(modelData.id);symbol:"link";flat:true;implicitHeight:28;onClicked:app.associate(modelData.id,modelData.address)}
        }
        IconButton {symbol:"refresh";hint:"刷新状态";enabled:modelData.status.state!=="checking";onClicked:library.refreshStatus(modelData.id)}
        ActionButton {text:"启动并加入";symbol:"play_arrow";highlighted:true;onClicked:app.joinServer(modelData.id,modelData.address)}
        IconButton {symbol:"edit";hint:"编辑服务器";onClicked:page.editPersonal(modelData)}
        IconButton {symbol:"close";hint:"移除服务器";onClicked:library.removeServer(modelData.id)}
       }
      }}
      Label { textFormat: Text.PlainText;visible:!library.servers.length;text:"添加服务器地址，关联实例后即可快捷加入";color:app.muted}
      ActionButton {text:"系统状态";symbol:"monitoring";visible:page.admin;flat:true;onClicked:host.open()}
     }
    }
    property string personalId:""
    function editPersonal(server){personalId=server?server.id:"";personalName.text=server?server.name:"";personalAddress.text=server?server.address:"";personalInstance.currentIndex=server?Math.max(0,personalInstance.model.findIndex(function(r){return r.id===library.links[server.id]})):0;personalServer.open()}
    AppDialog {id:personalServer;title:page.personalId?"编辑服务器":"添加服务器";modal:true;anchors.centerIn:parent;width:520;standardButtons:Dialog.NoButton
     ColumnLayout {width:parent.width;spacing:16
      TextField {id:personalName;placeholderText:"名称";Layout.fillWidth:true}
      TextField {id:personalAddress;placeholderText:"服务器地址（可含端口）";Layout.fillWidth:true}
      AppSelect {id:personalInstance;caption:"关联实例";model:[{id:"",name:"未关联实例"}].concat(app.allInstances);textRole:"name";valueRole:"id";Layout.fillWidth:true}
      Label { textFormat: Text.PlainText;text:library.error;visible:!!text;wrapMode:Text.Wrap;Layout.fillWidth:true;color:app.colors.error}
      RowLayout {Item {Layout.fillWidth:true}ActionButton {text:"取消";flat:true;onClicked:personalServer.close()}ActionButton {text:"保存";highlighted:true;onClicked:{if(library.saveServer(page.personalId,personalName.text,personalAddress.text,personalInstance.currentValue||""))personalServer.close()}}}
     }
    }
    AppDialog {
        id: confirm; anchors.centerIn: parent; width: Math.min(page.width - 32, 480); modal: true
        title: ({start:"启动",stop:"停止",backup:"备份",restore:"恢复",delete:"删除"})[page.pendingAction] + " · " + page.selected
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: { var args = {}; if (permission.text) args.permission_code = permission.text; if (backupName.text) args.backup_name = backupName.text; communityClient.serverAction(page.pendingAction,page.selected,args); permission.clear() }
        ColumnLayout { width: parent.width
            Label { textFormat: Text.PlainText; visible: page.pendingAction === "delete"; text: "将删除服务器文件，请确认已备份。"; wrapMode: Text.Wrap; Layout.fillWidth: true }
            TextField { id: permission; visible: !page.admin; placeholderText: "操作码"; echoMode: TextInput.Password; Layout.fillWidth: true }
            TextField { id: backupName; visible: page.pendingAction === "backup" || page.pendingAction === "restore"; placeholderText: "备份名称"; Layout.fillWidth: true }
        }
    }
    AppDialog {
        id: edit; anchors.centerIn: parent; width: Math.min(page.width - 32, 540); title: "编辑服务器"; modal: true
        standardButtons: Dialog.Save | Dialog.Cancel
        onAccepted: communityClient.serverAction("update",page.selected,{motd:motd.text})
        ColumnLayout { width: parent.width
            TextArea { id: motd; placeholderText: "MOTD"; wrapMode: TextEdit.Wrap; Layout.fillWidth: true; implicitHeight: 130 }
            ActionButton { text: "更换封面"; onClicked: { var file = desktop.chooseFile("图片 (*.png *.jpg *.jpeg *.webp)"); if (String(file)) communityClient.uploadCover(page.selected,file) } }
        }
    }
    AppDialog {
        id: backups; anchors.centerIn: parent; width: Math.min(page.width - 32, 540); height: 400; title: "备份"; modal: true; standardButtons: Dialog.Close
        ListView { anchors.fill: parent; clip: true; model: communityClient.backups
            delegate: ItemDelegate { required property var modelData; width: ListView.view.width; text: typeof modelData === "string" ? modelData : (modelData.name || modelData.backup_name || ""); onClicked: { backupName.text = text; page.pendingAction = "restore"; backups.close(); confirm.open() } }
        }
    }
    AppDialog {
        id: consoleDialog; anchors.centerIn: parent; width: Math.min(page.width - 32, 900); height: Math.min(page.height - 32, 650); title: page.selected; modal: true; standardButtons: Dialog.Close
        onClosed: communityClient.watchLogs("")
        ColumnLayout { anchors.fill: parent
            ScrollView { Layout.fillWidth: true; Layout.fillHeight: true
                TextArea { readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; text: communityClient.logLines.map(function(row) { return typeof row === "string" ? row : (row.message || row.line || JSON.stringify(row)) }).join("\n"); font.family: "Consolas"; font.pixelSize: 13 }
            }
            Label { textFormat: Text.PlainText; text: communityClient.commandResult; wrapMode: Text.Wrap; Layout.fillWidth: true }
            RowLayout { Layout.fillWidth: true
                ComboBox { id: commandType; model: ["RCON", "MCDR"] }
                TextField { id: command; placeholderText: "命令"; Layout.fillWidth: true; onAccepted: send.clicked() }
                ActionButton { id: send; text: "发送"; enabled: command.text.trim().length > 0; onClicked: { communityClient.sendCommand(page.selected,command.text,commandType.currentIndex === 1); command.clear() } }
            }
        }
    }
    AppDialog {
        id: upload; anchors.centerIn: parent; width: Math.min(page.width - 32, 540); title: "上传服务器"; modal: true; standardButtons: Dialog.Ok | Dialog.Cancel
        property url archive
        onAccepted: communityClient.uploadServer(archive,{name:uploadName.text,version:uploadVersion.text,launch_command:uploadCommand.text,motd:uploadMotd.text},true)
        ColumnLayout { width: parent.width
            TextField { id: uploadName; placeholderText: "服务器名称"; Layout.fillWidth: true }
            TextField { id: uploadVersion; placeholderText: "版本"; Layout.fillWidth: true }
            TextField { id: uploadCommand; placeholderText: "启动命令"; Layout.fillWidth: true }
            TextField { id: uploadMotd; placeholderText: "MOTD"; Layout.fillWidth: true }
            ActionButton { text: "选择 ZIP"; onClicked: upload.archive = desktop.chooseFile("ZIP (*.zip)") }
            Label { textFormat: Text.PlainText; text: String(upload.archive); elide: Text.ElideMiddle; Layout.fillWidth: true }
        }
    }
    AppDialog {
        id: host; anchors.centerIn: parent; width: Math.min(page.width - 32, 580); height: 400; title: "系统状态"; modal: true; standardButtons: Dialog.Close
        ScrollView { anchors.fill: parent; TextArea { text: JSON.stringify(communityClient.hostedStatus,null,2); readOnly: true; selectByMouse: true } }
    }
}
