import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: page; required property var app; clip: true; contentWidth: availableWidth
    ColumnLayout {
        width: page.availableWidth; spacing: 24
        Pane {
            Layout.fillWidth: true; padding: 24
            ColumnLayout {
                width: parent.width; spacing: 16
                RowLayout { Layout.fillWidth: true
                    Image { source: communityClient.imageUrl(communityClient.profile.avatar_url || ""); visible: communityClient.authenticated; Layout.preferredWidth: 64; Layout.preferredHeight: 64; asynchronous: true }
                    ColumnLayout { Layout.fillWidth: true
                        Label { text: communityClient.authenticated ? (communityClient.profile.username || "") : "登录"; font.pixelSize: 28; color: app.ink }
                        Label { visible: communityClient.authenticated; text: communityClient.profile.bio || ""; wrapMode: Text.Wrap; Layout.fillWidth: true; color: app.muted }
                    }
                    ActionButton { text: "设置"; flat: true; onClicked: app.showSettings() }
                }
                ColumnLayout {
                    visible: !communityClient.authenticated; Layout.fillWidth: true
                    TextField { id: username; placeholderText: "用户名"; Layout.fillWidth: true; Layout.maximumWidth: 430 }
                    TextField { id: password; placeholderText: "密码"; echoMode: TextInput.Password; Layout.fillWidth: true; Layout.maximumWidth: 430; onAccepted: { communityClient.login(username.text,password.text); password.clear() } }
                    RowLayout {
                        ActionButton { text: "登录"; highlighted: true; enabled: !communityClient.busy; onClicked: { communityClient.login(username.text,password.text); password.clear() } }
                        ActionButton { text: "注册"; enabled: !communityClient.busy; onClicked: { communityClient.registerAccount(username.text,password.text); password.clear() } }
                        ActionButton { text: "Microsoft"; flat: true; onClicked: communityClient.startMicrosoftLogin() }
                    }
                }
                ColumnLayout {
                    visible: communityClient.authenticated; Layout.fillWidth: true; spacing: 20
                    Label { text: "累计游玩"; font.pixelSize: 24; color: app.ink }
                    Label { text: app.duration(communityClient.playtime.reduce(function(sum,row) { return sum + Number(row.playtime_minutes || 0) },0)); font.pixelSize: 40; color: app.accent }
                    Repeater {
                        model: communityClient.playtime.slice(0,5)
                        delegate: ColumnLayout { required property var modelData; required property int index; Layout.fillWidth: true
                            RowLayout { Layout.fillWidth: true
                                Label { text: String(index + 1); color: app.accent; Layout.preferredWidth: 25 }
                                Label { text: modelData.server_name || modelData.name || ""; color: app.ink; Layout.fillWidth: true }
                                Label { text: app.duration(modelData.playtime_minutes); color: app.ink }
                            }
                            ProgressBar { value: Number(modelData.playtime_minutes || 0) / Math.max(1,Number(communityClient.playtime[0].playtime_minutes || 0)); Layout.fillWidth: true }
                        }
                    }
                    RowLayout { Layout.fillWidth: true
                        Label { text: "每日在线"; font.pixelSize: 24; color: app.ink; Layout.fillWidth: true }
                        TextField { id: date; text: communityClient.dailyDate; placeholderText: "YYYY-MM-DD"; Layout.preferredWidth: 150; onAccepted: communityClient.loadDaily(text) }
                        ActionButton { text: "查看"; flat: true; onClicked: communityClient.loadDaily(date.text) }
                    }
                    Repeater { model: communityClient.daily; delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Label { text: modelData.player || modelData.player_name || modelData.name || ""; color: app.ink; Layout.fillWidth: true }
                        Label { text: app.duration(modelData.playtime_minutes || modelData.minutes || 0); color: app.muted }
                    } }
                    ActionButton { visible: communityClient.profile.role === "admin"; text: "用户管理"; onClicked: { communityClient.loadUsers(""); users.open() } }
                    ActionButton { text: "退出登录"; flat: true; onClicked: communityClient.logout() }
                }
            }
        }
    }
    AppDialog {
        id: users; anchors.centerIn: parent; width: Math.min(page.width - 40, 700); height: Math.min(page.height - 40, 600); title: "用户管理"; modal: true; standardButtons: Dialog.Close
        ColumnLayout { anchors.fill: parent
            TextField { placeholderText: "搜索用户名"; Layout.fillWidth: true; onAccepted: communityClient.loadUsers(text) }
            ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: communityClient.users; clip: true
                delegate: RowLayout { required property var modelData; width: ListView.view.width
                    Label { text: modelData.username; Layout.fillWidth: true }
                    ComboBox { model: ["user", "admin"]; currentIndex: modelData.role === "admin" ? 1 : 0; onActivated: communityClient.setUserRole(modelData.id,currentText) }
                }
            }
        }
    }
}
