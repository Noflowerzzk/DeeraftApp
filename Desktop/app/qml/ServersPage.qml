import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: page; required property var app; padding: 24
    property string selected: ""
    property string pendingAction: ""
    property bool admin: communityClient.profile.role === "admin"
    function operate(action, name) { selected = name; pendingAction = action; confirm.open() }
    ColumnLayout {
        anchors.fill: parent; spacing: 16
        RowLayout { Layout.fillWidth: true
            Label { text: communityClient.authenticated ? "服务器" : "登录后查看服务器"; color: app.muted; Layout.fillWidth: true }
            ActionButton { text: "上传服务器"; visible: page.admin; onClicked: upload.open() }
            ActionButton { text: "系统状态"; visible: page.admin; flat: true; onClicked: host.open() }
        }
        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true; model: communityClient.servers; clip: true; spacing: 16
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width; implicitHeight: serverColumn.implicitHeight + 36; color: app.raised; radius: 20
                ColumnLayout {
                    id: serverColumn; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 18; spacing: 8
                    RowLayout { Layout.fillWidth: true
                        ColumnLayout { Layout.fillWidth: true
                            Label { text: modelData.name; font.pixelSize: 22; color: app.ink }
                            Label { text: app.clean(modelData.motd || modelData.description || ""); color: app.muted; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        }
                        Label { text: modelData.is_running || modelData.running || modelData.status === "running" ? "运行中" : "已停止"; color: app.accent }
                    }
                    Flow { Layout.fillWidth: true; spacing: 8
                        ActionButton { text: "启动"; onClicked: page.operate("start", modelData.name) }
                        ActionButton { text: "停止"; onClicked: page.operate("stop", modelData.name) }
                        ActionButton { text: "编辑"; visible: page.admin; onClicked: { page.selected = modelData.name; motd.text = modelData.motd || ""; edit.open() } }
                        ActionButton { text: "备份"; visible: page.admin; onClicked: page.operate("backup", modelData.name) }
                        ActionButton { text: "恢复"; visible: page.admin; onClicked: { page.selected = modelData.name; communityClient.loadBackups(page.selected); backups.open() } }
                        ActionButton { text: "日志 / 控制台"; visible: page.admin; onClicked: { page.selected = modelData.name; communityClient.watchLogs(page.selected); consoleDialog.open() } }
                        ActionButton { text: "删除"; visible: page.admin; flat: true; onClicked: page.operate("delete", modelData.name) }
                    }
                }
            }
        }
    }
    AppDialog {
        id: confirm; anchors.centerIn: parent; width: Math.min(page.width - 32, 480); modal: true
        title: ({start:"启动",stop:"停止",backup:"备份",restore:"恢复",delete:"删除"})[page.pendingAction] + " · " + page.selected
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: { var args = {}; if (permission.text) args.permission_code = permission.text; if (backupName.text) args.backup_name = backupName.text; communityClient.serverAction(page.pendingAction,page.selected,args); permission.clear() }
        ColumnLayout { width: parent.width
            Label { visible: page.pendingAction === "delete"; text: "将删除服务器文件，请确认已备份。"; wrapMode: Text.Wrap; Layout.fillWidth: true }
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
            Label { text: communityClient.commandResult; wrapMode: Text.Wrap; Layout.fillWidth: true }
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
        onAccepted: communityClient.uploadServer(archive,{name:uploadName.text,motd:uploadMotd.text},true)
        ColumnLayout { width: parent.width
            TextField { id: uploadName; placeholderText: "服务器名称"; Layout.fillWidth: true }
            TextField { id: uploadMotd; placeholderText: "MOTD"; Layout.fillWidth: true }
            ActionButton { text: "选择 ZIP"; onClicked: upload.archive = desktop.chooseFile("ZIP (*.zip)") }
            Label { text: String(upload.archive); elide: Text.ElideMiddle; Layout.fillWidth: true }
        }
    }
    AppDialog {
        id: host; anchors.centerIn: parent; width: Math.min(page.width - 32, 580); height: 400; title: "系统状态"; modal: true; standardButtons: Dialog.Close
        ScrollView { anchors.fill: parent; TextArea { text: JSON.stringify(communityClient.hostedStatus,null,2); readOnly: true; selectByMouse: true } }
    }
}
