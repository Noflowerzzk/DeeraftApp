import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: page
    required property var app
    property var mc: communityClient.community.mc || ({})
    property var kook: communityClient.community.kook || ({})
    property bool humans: true
    property bool expanded: false
    clip: true
    contentWidth: availableWidth
    ColumnLayout {
        width: page.availableWidth; spacing: 0
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 300
            color: "#102219"
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 32; spacing: 12
                Label { text: "Minecraft"; color: "#e0eee1"; font.pixelSize: 22 }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: page.mc.online_count !== undefined ? String(page.mc.online_count) : "—"; font.pixelSize: 78; color: "#9ad4ab"; font.weight: Font.Medium }
                    Label { text: "在线"; color: "#dce9dc"; font.pixelSize: 19; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 18 }
                    Item { Layout.fillWidth: true }
                    Label { text: app.clean(page.mc.motd) || (communityClient.authenticated ? "等待服务器状态" : "登录后查看社区"); color: "#e0eee1"; font.pixelSize: 26; wrapMode: Text.Wrap; Layout.maximumWidth: page.width * 0.48 }
                }
                Label { text: (page.mc.version || "") + (page.mc.latency_ms !== undefined ? "    " + Math.round(page.mc.latency_ms) + " ms" : ""); color: "#aec2b1"; font.pixelSize: 15 }
                Item { Layout.fillHeight: true }
            }
        }
        Rectangle {
            Layout.fillWidth: true; color: app.surface; radius: 28
            Layout.topMargin: -28
            implicitHeight: lower.implicitHeight + 64
            ColumnLayout {
                id: lower; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 32; spacing: 28
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "在线玩家"; color: app.ink; font.pixelSize: 24; Layout.fillWidth: true }
                    TabBar {
                        currentIndex: page.humans ? 0 : 1
                        onCurrentIndexChanged: page.humans = currentIndex === 0
                        TabButton { text: "真人"; width: 76 }
                        TabButton { text: "全部"; width: 76 }
                    }
                }
                Flow {
                    Layout.fillWidth: true; spacing: 20
                    property var players: page.humans ? (page.mc.human_players || []) : (page.mc.players || [])
                    Repeater {
                        model: page.expanded ? parent.players : parent.players.slice(0, 12)
                        delegate: Column {
                            required property var modelData
                            width: 100; spacing: 8
                            Image { anchors.horizontalCenter: parent.horizontalCenter; width: 56; height: 56; source: "https://mc-heads.net/avatar/" + encodeURIComponent(modelData) + "/64"; fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: false }
                            Label { width: parent.width; text: modelData; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; color: app.ink; ToolTip.visible: hover.hovered; ToolTip.text: modelData; HoverHandler { id: hover } }
                        }
                    }
                }
                Label { visible: (page.mc.players || []).length === 0; text: communityClient.authenticated ? "暂无在线玩家" : "请在“我的”登录"; color: app.muted }
                ActionButton { visible: (page.mc.players || []).length > 12; text: page.expanded ? "收起" : "展开"; flat: true; onClicked: page.expanded = !page.expanded }
                Label { text: "KOOK"; color: app.ink; font.pixelSize: 24 }
                Repeater {
                    model: page.kook.channels || []
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 8
                        RowLayout { Layout.fillWidth: true
                            Label { text: modelData.name || ""; color: app.ink; font.pixelSize: 17; Layout.fillWidth: true }
                            Label { text: String((modelData.users || []).length); color: app.muted }
                        }
                        Flow { Layout.fillWidth: true; spacing: 12
                            Repeater { model: modelData.users || []; delegate: Row { required property var modelData; spacing: 8
                                Image { width: 28; height: 28; source: modelData.avatar || ""; asynchronous: true }
                                Label { text: modelData.nickname || modelData.username || modelData.name || ""; color: app.muted }
                            } }
                        }
                    }
                }
                Label { visible: (page.kook.channels || []).length === 0; text: "暂无语音频道"; color: app.muted }
                RowLayout { Layout.fillWidth: true
                    Label { text: "直播间"; color: app.ink; font.pixelSize: 24; Layout.fillWidth: true }
                    ActionButton { visible: communityClient.profile.role === "admin"; text: "管理"; flat: true; onClicked: liveEditor.open() }
                }
                Repeater { model: communityClient.liveRooms; delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Label { text: modelData.title || modelData.name || String(modelData.room_id || ""); Layout.fillWidth: true; color: app.ink }
                    ActionButton { text: "观看"; onClicked: desktop.openLive(String(modelData.room_id || modelData.id)) }
                } }
            }
        }
    }
    AppDialog {
        id: liveEditor; title: "直播间"; anchors.centerIn: parent; width: Math.min(page.width - 40, 580); modal: true
        standardButtons: Dialog.Save | Dialog.Cancel
        onOpened: liveJson.text = JSON.stringify(communityClient.liveRooms, null, 2)
        onAccepted: { try { communityClient.saveLiveRooms(JSON.parse(liveJson.text)) } catch(e) { liveJson.text = String(e) } }
        TextArea { id: liveJson; width: parent.width; height: 300; wrapMode: TextEdit.Wrap; selectByMouse: true }
    }
}
