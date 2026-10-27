import QtQuick
import Qcm.Material as MD
import QtQuick.Controls
import QtQuick.Layouts

MD.Pane {
    id: page; objectName: "serversPage"; required property var app; padding: 24; backgroundColor: app.surface
    property string selected: ""
    property string pendingAction: ""
    property bool admin: communityClient.profile.role === "admin"
    function operate(action, name) { selected = name; pendingAction = action; confirm.open() }
    property bool onlyRunning:false
    function serverRunning(server){var state=communityClient.hostedStatus;if(state.server_name===server.name && state.is_running!==undefined)return !!state.is_running;return !!(server.is_running||server.running||server.status==="running")}

    ScrollView {
     id: serverScroll
     anchors.fill: parent
     contentWidth: availableWidth
     clip: true
     ColumnLayout {
      width: serverScroll.availableWidth
      spacing: 24
      RowLayout {
       Layout.fillWidth: true
       MD.ButtonGroupContainer {
        variant: MD.ButtonGroupContainer.Connected; size: MD.Enum.S; animateWidth: false
        MD.ToggleButton { text: "全部服务器"; checked: !page.onlyRunning; icon.name: checked?"check":""; mdState.type: MD.Enum.BtFilledTonal; onCheckedChangeRequested: page.onlyRunning=false }
        MD.ToggleButton { text: "运行中"; checked: page.onlyRunning; icon.name: checked?"check":""; mdState.type: MD.Enum.BtFilledTonal; onCheckedChangeRequested: page.onlyRunning=true }
       }
       Item { Layout.fillWidth: true }
       ActionButton { text: "上传服务器"; symbol: "upload"; highlighted: true; visible: page.admin; onClicked: upload.open() }
      }
      Flow {
       id: serverFlow
       Layout.fillWidth: true
       spacing: 24
       Repeater {
        model: communityClient.servers.filter(function(server){return !page.onlyRunning || page.serverRunning(server)})
        MD.Pane {
         id: serverCard
         objectName: "serverCard"
         required property var modelData
         readonly property bool running: page.serverRunning(modelData)
         readonly property int artHeight: app.width<=1050?190:240
         width: serverFlow.width<760?serverFlow.width:(serverFlow.width-24)/2
         height: artHeight+40+serverBody.implicitHeight+24
         radius: 32
         backgroundColor: app.panel
         RoundedImage { x: 12; y: 12; width: parent.width-24; height: serverCard.artHeight; radius: 24; source: serverCard.modelData.cover_url?communityClient.imageUrl(serverCard.modelData.cover_url):"qrc:/deeraft/images/village.png" }
         MD.Pane { x: 28; y: 28; height: 34; width: stateText.implicitWidth+24; radius: 17; backgroundColor: serverCard.running?app.colors.primaryContainer:app.colors.surfaceContainerHigh; AppLabel { id: stateText; anchors.centerIn: parent; text: serverCard.running?"● 运行中":"● 已停止"; color: serverCard.running?app.colors.onPrimaryContainer:app.muted; font.pixelSize: 13; font.weight: 550 } }
         ColumnLayout {
          id: serverBody
          x: 24; y: serverCard.artHeight+40; width: parent.width-48
          spacing: 12
          RowLayout {
           Layout.fillWidth: true
           AppLabel { text: serverCard.modelData.name; font.pixelSize: 28; color: app.ink; Layout.fillWidth: true; elide: Text.ElideRight }
           IconButton { symbol: "more_vert"; hint: "服务器操作"; visible: page.admin; onClicked: {page.selected=serverCard.modelData.name;motd.text=serverCard.modelData.motd||"";serverMenu.showAt(this)} }
          }
          AppLabel { text: serverCard.modelData.version||app.clean(serverCard.modelData.description||serverCard.modelData.motd||""); color: app.muted; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
          RowLayout {
           Layout.fillWidth: true
           Layout.topMargin: 8
           Layout.bottomMargin: 8
           spacing: 20
           MD.Icon { name: "group"; size: 20; color: app.muted }
           AppLabel { text: (serverCard.modelData.online_players??serverCard.modelData.player_count??"—")+" 在线"; color: app.muted; font.pixelSize: 13 }
           MD.Icon { name: "memory"; size: 20; color: app.muted }
           AppLabel { text: serverCard.modelData.memory_usage||"—"; color: app.muted; font.pixelSize: 13 }
          }
          MD.Divider { Layout.fillWidth: true; color: app.colors.outlineVariant }
          RowLayout {
           Layout.fillWidth: true
           spacing: 8
           ActionButton { text: app.linkedName(serverCard.modelData.name); symbol: "link"; flat: true; font.pixelSize: 12; onClicked: app.associate(serverCard.modelData.name,serverCard.modelData.address||"") }
           Item { Layout.fillWidth: true }
           ActionButton { text: "启动实例并加入"; symbol: "sports_esports"; flat: true; font.pixelSize: 12; onClicked: app.joinServer(serverCard.modelData.name,app.serverAddress(serverCard.modelData.name,serverCard.modelData.address||"")) }
          }
          RowLayout {
           Layout.fillWidth: true
           spacing: 8
           ActionButton { text: serverCard.running?"停止":"启动"; symbol: serverCard.running?"stop":"play_arrow"; highlighted: !serverCard.running; onClicked: page.operate(serverCard.running?"stop":"start",serverCard.modelData.name) }
           ActionButton { text: "控制台"; symbol: "terminal"; visible: page.admin; flat: true; onClicked: {page.selected=serverCard.modelData.name;communityClient.watchLogs(page.selected);consoleDialog.open()} }
           Item { Layout.fillWidth: true }
           IconButton { symbol: "backup"; hint: "备份"; visible: page.admin; onClicked: page.operate("backup",serverCard.modelData.name) }
          }
         }
        }
       }
      }
      AppLabel { visible: !communityClient.servers.length; text: communityClient.authenticated?"暂无服务器":"登录后查看社区服务器"; color: app.muted }
      RowLayout {
       Layout.fillWidth: true
       ColumnLayout { Layout.fillWidth: true; spacing: 4; AppLabel { Layout.fillWidth: true; text: "第三方服务器"; font.pixelSize: 20; font.weight: 600; color: app.ink } AppLabel { Layout.fillWidth: true; text: "个人快捷加入"; font.pixelSize: 13; color: app.muted } }
       ActionButton { text: "添加服务器"; symbol: "add"; onClicked: page.editPersonal(null) }
      }
      MD.Pane {
       Layout.fillWidth: true
       implicitHeight: personalList.implicitHeight+24
       radius: 24; backgroundColor: app.panel
       ColumnLayout {
        id: personalList
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12
        spacing: 0
        Repeater {
         model: library.servers
         RowLayout {
          id: personalRow
          required property var modelData
          Layout.fillWidth: true
          Layout.margins: 12
          spacing: 12
          MD.Pane { Layout.preferredWidth: 48; Layout.preferredHeight: 48; radius: 16; backgroundColor: app.colors.secondaryContainer; MD.Icon { anchors.centerIn: parent; name: "public"; size: 28; color: app.colors.onSecondaryContainer } }
          ColumnLayout {
           Layout.fillWidth: true
           spacing: 6
           RowLayout { Layout.fillWidth: true; AppLabel { text: personalRow.modelData.name; font.pixelSize: 18; color: app.ink; elide: Text.ElideRight } MD.Pane { implicitWidth: statusLabel.implicitWidth+18; implicitHeight: 26; radius: 13; backgroundColor: personalRow.modelData.status.state==="online"?app.colors.primaryContainer:app.colors.surfaceContainerHigh; AppLabel { id: statusLabel; anchors.centerIn: parent; text: "● "+personalRow.modelData.status.label; color: personalRow.modelData.status.state==="unavailable"?app.colors.error:app.muted; font.pixelSize: 12 } } }
           AppLabel { text: personalRow.modelData.address; color: app.muted; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideMiddle }
           AppLabel { text: (personalRow.modelData.status.version||"版本 —")+"    "+(personalRow.modelData.status.online!==undefined?personalRow.modelData.status.online+" / "+personalRow.modelData.status.max:"—")+" 在线"+(personalRow.modelData.status.latency!==undefined?"    "+personalRow.modelData.status.latency+" ms":""); color: app.muted; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
           ActionButton { text: app.linkedName(personalRow.modelData.id); symbol: "link"; flat: true; font.pixelSize: 12; onClicked: app.associate(personalRow.modelData.id,personalRow.modelData.address) }
          }
          IconButton { symbol: "refresh"; hint: "刷新状态"; enabled: personalRow.modelData.status.state!=="checking"; onClicked: library.refreshStatus(personalRow.modelData.id) }
          ActionButton { text: "启动并加入"; symbol: "play_arrow"; highlighted: true; onClicked: app.joinServer(personalRow.modelData.id,personalRow.modelData.address) }
          IconButton { symbol: "edit"; hint: "编辑第三方服务器"; onClicked: page.editPersonal(personalRow.modelData) }
          IconButton { symbol: "close"; hint: "移除第三方服务器"; onClicked: library.removeServer(personalRow.modelData.id) }
         }
        }
        RowLayout { visible: !library.servers.length; Layout.fillWidth: true; Layout.margins: 12; spacing: 16; MD.Icon { name: "public"; size: 24; color: app.muted } AppLabel { text: "添加服务器地址，关联实例后即可快捷加入"; font.pixelSize: 13; color: app.muted; Layout.fillWidth: true } ActionButton { text: "添加服务器"; flat: true; onClicked: page.editPersonal(null) } }
       }
      }
      ActionButton { text: "系统状态"; symbol: "monitoring"; visible: page.admin; flat: true; onClicked: host.open() }
     }
    }
    AppMenu {
     id: serverMenu
     MD.MenuItem { text: "编辑"; icon.name: "edit"; onTriggered: edit.open() }
     MD.MenuItem { text: "备份"; icon.name: "backup"; onTriggered: page.operate("backup",page.selected) }
     MD.MenuItem { text: "恢复备份"; icon.name: "restore"; onTriggered: {communityClient.loadBackups(page.selected);backups.open()} }
     MD.Divider {}
     MD.MenuItem { text: "删除服务器"; icon.name: "delete"; onTriggered: page.operate("delete",page.selected) }
    }
    property string personalId:""
    function editPersonal(server){personalId=server?server.id:"";personalName.text=server?server.name:"";personalAddress.text=server?server.address:"";personalInstance.currentIndex=server?Math.max(0,personalInstance.model.findIndex(function(r){return r.id===library.links[server.id]})):0;personalServer.open()}
    AppDialog {id:personalServer;title:page.personalId?"编辑服务器":"添加服务器";modal:true;width:520;standardButtons:Dialog.NoButton
     ColumnLayout {width:parent.width;spacing:16
      AppTextField {id:personalName;placeholderText:"名称";Layout.fillWidth:true}
      AppTextField {id:personalAddress;placeholderText:"服务器地址（可含端口）";Layout.fillWidth:true}
      AppSelect {id:personalInstance;caption:"关联实例";model:[{id:"",name:"未选择实例"}].concat(app.instanceChoices);textRole:"name";valueRole:"id";Layout.fillWidth:true}
      AppLabel { textFormat: Text.PlainText;text:library.error;visible:!!text;wrapMode:Text.Wrap;Layout.fillWidth:true;color:app.colors.error}
      RowLayout {Item {Layout.fillWidth:true}ActionButton {text:"取消";flat:true;onClicked:personalServer.close()}ActionButton {text:"保存";highlighted:true;onClicked:{if(library.saveServer(page.personalId,personalName.text,personalAddress.text,personalInstance.currentValue||""))personalServer.close()}}}
     }
    }
    AppDialog {
        id: confirm; width: Math.min(page.width - 32, 480); modal: true
        title: ({start:"启动",stop:"停止",backup:"备份",restore:"恢复",delete:"删除"})[page.pendingAction] + " · " + page.selected
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: { var args = {}; if (permission.text) args.permission_code = permission.text; if (backupName.text) args.backup_name = backupName.text; communityClient.serverAction(page.pendingAction,page.selected,args); permission.clear() }
        ColumnLayout { width: parent.width
            AppLabel { textFormat: Text.PlainText; visible: page.pendingAction === "delete"; text: "将删除服务器文件，请确认已备份。"; wrapMode: Text.Wrap; Layout.fillWidth: true }
            AppTextField { id: permission; visible: !page.admin; placeholderText: "操作码"; echoMode: TextInput.Password; Layout.fillWidth: true }
            AppTextField { id: backupName; visible: page.pendingAction === "backup" || page.pendingAction === "restore"; placeholderText: "备份名称"; Layout.fillWidth: true }
        }
    }
    AppDialog {
        id: edit; width: Math.min(page.width - 32, 540); title: "编辑服务器"; modal: true
        standardButtons: Dialog.Save | Dialog.Cancel
        onAccepted: communityClient.serverAction("update",page.selected,{motd:motd.text})
        ColumnLayout { width: parent.width
            TextArea { id: motd; placeholderText: "MOTD"; wrapMode: TextEdit.Wrap; Layout.fillWidth: true; implicitHeight: 130 }
            ActionButton { text: "更换封面"; onClicked: { var file = desktop.chooseFile("图片 (*.png *.jpg *.jpeg *.webp)"); if (String(file)) communityClient.uploadCover(page.selected,file) } }
        }
    }
    AppDialog {
        id: backups; width: Math.min(page.width - 32, 540); height: 400; title: "备份"; modal: true; standardButtons: Dialog.Close
        ListView { anchors.fill: parent; clip: true; model: communityClient.backups
            delegate: ItemDelegate { required property var modelData; width: ListView.view.width; text: typeof modelData === "string" ? modelData : (modelData.name || modelData.backup_name || ""); onClicked: { backupName.text = text; page.pendingAction = "restore"; backups.close(); confirm.open() } }
        }
    }
    AppDialog {
        id: consoleDialog; width: Math.min(page.width - 32, 900); height: Math.min(page.height - 32, 650); title: page.selected; modal: true; standardButtons: Dialog.Close
        onClosed: communityClient.watchLogs("")
        ColumnLayout { anchors.fill: parent
            ScrollView { Layout.fillWidth: true; Layout.fillHeight: true
                TextArea { readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; text: communityClient.logLines.map(function(row) { return typeof row === "string" ? row : (row.message || row.line || JSON.stringify(row)) }).join("\n"); font.family: "Consolas"; font.pixelSize: 13 }
            }
            AppLabel { textFormat: Text.PlainText; text: communityClient.commandResult; wrapMode: Text.Wrap; Layout.fillWidth: true }
            RowLayout { Layout.fillWidth: true
                AppSelect { id: commandType; model: ["RCON", "MCDR"] }
                AppTextField { id: command; placeholderText: "命令"; Layout.fillWidth: true; onAccepted: send.clicked() }
                ActionButton { id: send; text: "发送"; enabled: command.text.trim().length > 0; onClicked: { communityClient.sendCommand(page.selected,command.text,commandType.currentIndex === 1); command.clear() } }
            }
        }
    }
    AppDialog {
        id: upload; width: Math.min(page.width - 32, 540); title: "上传服务器"; modal: true; standardButtons: Dialog.Ok | Dialog.Cancel
        property url archive
        onAccepted: communityClient.uploadServer(archive,{name:uploadName.text,version:uploadVersion.text,launch_command:uploadCommand.text,motd:uploadMotd.text},true)
        ColumnLayout { width: parent.width
            AppTextField { id: uploadName; placeholderText: "服务器名称"; Layout.fillWidth: true }
            AppTextField { id: uploadVersion; placeholderText: "版本"; Layout.fillWidth: true }
            AppTextField { id: uploadCommand; placeholderText: "启动命令"; Layout.fillWidth: true }
            AppTextField { id: uploadMotd; placeholderText: "MOTD"; Layout.fillWidth: true }
            ActionButton { text: "选择 ZIP"; onClicked: upload.archive = desktop.chooseFile("ZIP (*.zip)") }
            AppLabel { textFormat: Text.PlainText; text: String(upload.archive); elide: Text.ElideMiddle; Layout.fillWidth: true }
        }
    }
    AppDialog {
        id: host; width: Math.min(page.width - 32, 580); height: 400; title: "系统状态"; modal: true; standardButtons: Dialog.Close
        ScrollView { anchors.fill: parent; TextArea { text: JSON.stringify(communityClient.hostedStatus,null,2); readOnly: true; selectByMouse: true } }
    }
}
