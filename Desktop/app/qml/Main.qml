import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Pane {
    id: root
    padding: 0
    Material.theme: desktop.dark ? Material.Dark : Material.Light
    Material.primary: desktop.dark ? "#9ad4ab" : "#356b4a"
    Material.accent: desktop.dark ? "#9ad4ab" : "#356b4a"
    Material.background: surface
    Material.foreground: ink
    property color surface: desktop.dark ? "#101712" : "#f5faf4"
    property color raised: desktop.dark ? "#1b261e" : "#eaf1e8"
    property color ink: desktop.dark ? "#e1e9df" : "#18211a"
    property color muted: desktop.dark ? "#a6b5a8" : "#56665a"
    property color accent: desktop.dark ? "#9ad4ab" : "#356b4a"
    property int page: 0
    property string pageTitle: ["社区", "启动器", "服务器", "聊天", "我的"][page]
    background: Rectangle { color: root.surface }
    function clean(text) { return String(text || "").replace(/§[0-9a-fk-or]/gi, "") }
    function duration(minutes) { return Number(minutes || 0) < 60 ? Math.round(Number(minutes || 0)) + " 分钟" : (Number(minutes) / 60).toFixed(1) + " 小时" }
    function showSettings() { settings.open() }
    function closeSettings() { settings.close() }
    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: root.width < 1050 ? 96 : 184
            color: root.raised
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 8
                Label { text: root.width < 1050 ? "D" : "DeeraftApp"; color: root.ink; font.pixelSize: 23; font.weight: Font.DemiBold; Layout.topMargin: 20; Layout.bottomMargin: 36; Layout.alignment: Qt.AlignHCenter }
                Repeater {
                    model: [{name:"社区",symbol:"◉"},{name:"启动器",symbol:"▦"},{name:"服务器",symbol:"▤"},{name:"聊天",symbol:"▢"},{name:"我的",symbol:"○"}]
                    delegate: ActionButton {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true; Layout.preferredHeight: 54
                        text: root.width < 1050 ? modelData.name : modelData.symbol + "   " + modelData.name
                        highlighted: root.page === index
                        flat: root.page !== index
                        onClicked: root.page = index
                    }
                }
                Item { Layout.fillHeight: true }
                ActionButton { text: "下载任务"; flat: true; Layout.fillWidth: true; onClicked: tasksDrawer.open() }
                ActionButton { text: "设置"; flat: true; Layout.fillWidth: true; onClicked: root.showSettings() }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
            RowLayout {
                Layout.fillWidth: true; Layout.margins: 24; Layout.bottomMargin: 12
                Label { text: root.pageTitle; font.pixelSize: 28; font.weight: Font.Medium; color: root.ink; Layout.fillWidth: true }
                BusyIndicator { running: communityClient.busy; visible: running; Layout.preferredWidth: 32; Layout.preferredHeight: 32 }
                ActionButton { text: "刷新"; flat: true; onClicked: communityClient.refresh() }
            }
            Rectangle {
                visible: communityClient.error.length > 0
                color: desktop.dark ? "#532c2b" : "#ffdad6"
                Layout.fillWidth: true; implicitHeight: errorRow.implicitHeight + 16
                RowLayout { id: errorRow; anchors.fill: parent; anchors.margins: 8
                    Label { text: communityClient.error; wrapMode: Text.Wrap; Layout.fillWidth: true; color: desktop.dark ? "#ffdad6" : "#410002" }
                    ToolButton { text: "关闭"; onClicked: communityClient.clearError() }
                }
            }
            StackLayout {
                id: stack
                Layout.fillWidth: true; Layout.fillHeight: true; currentIndex: root.page
                CommunityPage { app: root }
                LauncherPage { app: root }
                ServersPage { app: root }
                ChatPage { app: root }
                ProfilePage { app: root }
                onCurrentIndexChanged: { enter.restart() }
                SequentialAnimation { id: enter; NumberAnimation { target: stack; property: "opacity"; from: 0.35; to: 1; duration: 180; easing.type: Easing.OutCubic } }
            }
        }
    }
    SettingsDialog { id: settings; app: root; anchors.centerIn: parent; width: Math.min(root.width - 64, 620); height: Math.min(root.height - 48, 740) }
    Drawer {
        id: tasksDrawer; edge: Qt.RightEdge; width: Math.min(root.width - 60, 500); height: root.height
        Material.theme: root.Material.theme
        Material.primary: root.Material.primary
        Material.accent: root.Material.accent
        Material.background: root.surface
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 24; spacing: 12
            Label { text: "下载任务"; font.pixelSize: 24 }
            ProgressBar { visible: communityClient.uploading; value: communityClient.uploadProgress; Layout.fillWidth: true }
            ActionButton { visible: communityClient.uploading; text: "取消上传"; onClicked: communityClient.cancelUpload() }
            Label { visible: desktop.tasks.length === 0 && !communityClient.uploading; text: "暂无任务"; color: root.muted }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; model: desktop.tasks; clip: true; spacing: 20
                delegate: ColumnLayout {
                    required property var modelData
                    width: ListView.view.width
                    Label { text: modelData.name || modelData.status || "下载"; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    Label { text: modelData.state + (modelData.error ? " · " + modelData.error : ""); wrapMode: Text.Wrap; Layout.fillWidth: true; color: root.muted }
                    ProgressBar { from: 0; to: Math.max(1, modelData.total); value: modelData.current; indeterminate: modelData.total <= 0 && modelData.state === "进行中"; Layout.fillWidth: true }
                    ActionButton { text: "取消"; visible: modelData.canCancel; onClicked: desktop.cancelTask(modelData.id) }
                }
            }
        }
    }
}
