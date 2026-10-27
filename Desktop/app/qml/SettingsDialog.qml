import QtQuick
import Qcm.Material as MD
import QtQuick.Controls
import QtQuick.Layouts

AppDialog {
    id: dialog; required property var app; title: "设置"; modal: true; standardButtons: Dialog.Close
    ScrollView {
        anchors.fill: parent; contentWidth: availableWidth; clip: true
        ColumnLayout {
            width: parent.width; spacing: 20
            AppLabel { textFormat: Text.PlainText; text: "外观"; font.pixelSize: 20 }
            AppSelect { model: ["跟随系统", "浅色", "深色"]; currentIndex: ["system","light","dark"].indexOf(desktop.theme); onActivated: desktop.theme = ["system","light","dark"][currentIndex]; Layout.fillWidth: true }
            MD.Switch { text: "减少动态效果"; checked: library.reducedMotion; onCheckedChangeRequested: function(checked) { library.reducedMotion = checked } }
            AppLabel { textFormat: Text.PlainText; text: "下载源"; font.pixelSize: 20 }
            AppSelect { model: ["自动（国内优先）", "国内源", "官方源"]; currentIndex: downloadSources.mode; onActivated: downloadSources.mode = currentIndex; Layout.fillWidth: true }
            AppLabel { textFormat: Text.PlainText; text: "Minecraft 账号"; font.pixelSize: 20 }
            Repeater { model: desktop.accounts; delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                MD.RadioButton { text: modelData.name + " · " + modelData.type; selected: modelData.selected; onSelectionRequested: desktop.selectAccount(modelData.uuid); Layout.fillWidth: true }
            } }
            RowLayout { Layout.fillWidth: true
                AppTextField { id: offlineName; placeholderText: "离线玩家名"; Layout.fillWidth: true }
                ActionButton { text: "添加"; onClicked: { desktop.addOfflineAccount(offlineName.text); offlineName.clear() } }
            }
            AppLabel { textFormat: Text.PlainText; text: desktop.error; visible: text.length > 0; wrapMode: Text.Wrap; Layout.fillWidth: true }
            RowLayout {
                ActionButton { text: "正版登录 / 管理"; onClicked: desktop.action("actionManageAccounts") }
                ActionButton { text: "第三方登录"; onClicked: thirdParty.open() }
            }
            ColumnLayout {
                visible: communityClient.authenticated; Layout.fillWidth: true
                AppLabel { textFormat: Text.PlainText; text: "个人资料"; font.pixelSize: 20 }
                AppTextField { id: username; text: communityClient.profile.username || ""; placeholderText: "用户名"; Layout.fillWidth: true }
                TextArea { id: bio; text: communityClient.profile.bio || ""; placeholderText: "简介"; Layout.fillWidth: true; wrapMode: TextEdit.Wrap }
                RowLayout {
                    ActionButton { text: "保存"; onClicked: communityClient.updateProfile(username.text,bio.text) }
                    ActionButton { text: "更换头像"; onClicked: { var file = desktop.chooseFile("图片 (*.png *.jpg *.jpeg *.webp)"); if (String(file)) communityClient.uploadAvatar(file) } }
                }
            }
            ActionButton { text: "启动器高级设置"; flat: true; onClicked: desktop.action("actionSettings") }
            RowLayout {
                ActionButton { text: "启动器日志"; flat: true; onClicked: desktop.action("actionViewLog") }
                ActionButton { text: "关于"; flat: true; onClicked: desktop.action("actionAbout") }
            }
            AppLabel { textFormat: Text.PlainText; text: "DeeraftApp · Prism 11.1.1"; color: app.muted }
        }
    }
    AppDialog {
        id: thirdParty; width: Math.min(dialog.width - 20, 550); height: Math.min(dialog.height - 20, 600); title: "第三方登录"; modal: true; standardButtons: Dialog.Close
        onClosed: externalAccounts.cancel()
        ScrollView { anchors.fill: parent; contentWidth: availableWidth
            ColumnLayout { width: parent.width; spacing: 12
                AppSelect { id: provider; model: ["Authlib-injector", "Yggdrasil Connect"]; Layout.fillWidth: true }
                AppTextField { id: server; placeholderText: "Yggdrasil API 地址（HTTPS）"; Layout.fillWidth: true }
                AppTextField { id: user; visible: provider.currentIndex === 0; placeholderText: "账号"; Layout.fillWidth: true }
                AppTextField { id: pass; visible: provider.currentIndex === 0; placeholderText: "密码"; echoMode: TextInput.Password; Layout.fillWidth: true }
                AppTextField { id: discovery; visible: provider.currentIndex === 1; placeholderText: "OpenID 发现地址"; Layout.fillWidth: true }
                AppTextField { id: clientId; visible: provider.currentIndex === 1; placeholderText: "Client ID"; Layout.fillWidth: true }
                ActionButton { text: "登录"; highlighted: true; enabled: !externalAccounts.busy; onClicked: { if (provider.currentIndex === 0) { externalAccounts.loginAuthlib(server.text,user.text,pass.text); pass.clear() } else externalAccounts.startConnect(discovery.text,clientId.text,server.text) } }
                BusyIndicator { running: externalAccounts.busy; visible: running }
                AppLabel { textFormat: Text.PlainText; text: externalAccounts.deviceCode; visible: text.length > 0; font.pixelSize: 30 }
                ActionButton { text: "打开授权页面"; visible: externalAccounts.verificationUri.length > 0; onClicked: externalAccounts.openVerificationPage() }
                AppLabel { textFormat: Text.PlainText; text: externalAccounts.error; visible: text.length > 0; wrapMode: Text.Wrap; Layout.fillWidth: true }
                Repeater { model: externalAccounts.profiles; delegate: ActionButton { required property var modelData; text: modelData.name; onClicked: externalAccounts.selectProfile(modelData.id) } }
            }
        }
    }
}
