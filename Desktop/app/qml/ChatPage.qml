import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: page; required property var app; padding: 24
    ListView {
        id: list; anchors.fill: parent; model: communityClient.chat; clip: true; spacing: 20
        property bool follow: true
        onMovementStarted: follow = false
        onCountChanged: if (follow) Qt.callLater(function() { list.positionViewAtEnd() })
        delegate: RowLayout {
            required property var modelData
            width: ListView.view.width; spacing: 16
            Image { source: modelData.player ? "https://mc-heads.net/avatar/" + encodeURIComponent(modelData.player) + "/48" : ""; Layout.preferredWidth: 40; Layout.preferredHeight: 40; Layout.alignment: Qt.AlignTop; asynchronous: true; smooth: false }
            ColumnLayout { Layout.fillWidth: true; spacing: 6
                RowLayout { Layout.fillWidth: true
                    Label { text: modelData.player || modelData.sender || "Minecraft"; color: app.accent; font.weight: Font.Medium }
                    Label { text: modelData.time || ""; color: app.muted; font.pixelSize: 12; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
                }
                TextEdit { text: modelData.message || modelData.content || ""; color: app.ink; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; Layout.fillWidth: true; font.pixelSize: 16 }
            }
        }
        Label { anchors.centerIn: parent; visible: list.count === 0; text: communityClient.authenticated ? "暂无聊天消息" : "登录后查看聊天"; color: app.muted }
        ScrollBar.vertical: ScrollBar { }
    }
    ActionButton { anchors.right: parent.right; anchors.bottom: parent.bottom; text: "最新消息"; visible: !list.follow; onClicked: { list.follow = true; list.positionViewAtEnd() } }
}
