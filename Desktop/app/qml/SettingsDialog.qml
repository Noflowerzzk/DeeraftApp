import QtQuick
import Qcm.Material as MD
import QtQuick.Controls
import QtQuick.Layouts

AppDialog {
    id: dialog; required property var app; title: "设置"; modal: true; standardButtons: Dialog.Close
    ScrollView {
        id:settingsScroll;objectName:"settingsScroll"
        anchors.fill: parent; contentWidth: availableWidth; clip: true
        ScrollBar.vertical.policy: ScrollBar.AlwaysOn
        contentHeight:settingsContent.implicitHeight+16
        ColumnLayout {
            id:settingsContent;width: settingsScroll.availableWidth-Math.max(12,settingsScroll.effectiveScrollBarWidth+8); spacing: 20
            AppLabel { color:app.ink;textFormat: Text.PlainText; text: "外观"; font.pixelSize: 20 }
            AppSelect { model: ["跟随系统", "浅色", "深色"]; currentIndex: ["system","light","dark"].indexOf(desktop.theme); onActivated: desktop.theme = ["system","light","dark"][currentIndex]; Layout.fillWidth: true }
            AppLabel {text:"Nature 配色";color:app.muted}
            Flow {
                Layout.fillWidth:true;spacing:8
                Repeater {model:app.natureThemes;delegate:MD.Button {
                    required property var modelData
                    objectName:"natureTheme_"+modelData.id
                    text:modelData.name;icon.name:desktop.colorTheme===modelData.id?"check":"circle"
                    icon.color:desktop.colorTheme===modelData.id?app.colors.onSecondaryContainer:modelData.seed
                    mdState.type:MD.Enum.BtFilledTonal
                    onClicked:desktop.colorTheme=modelData.id
                    Accessible.description:"Nature "+modelData.name+"配色"
                }}
            }
            RowLayout {Layout.fillWidth:true;AppLabel {text:"减少动态效果";color:app.ink;Layout.fillWidth:true}MD.Switch {checked:library.reducedMotion;onCheckedChangeRequested:function(checked){library.reducedMotion=checked}}}
            AppLabel { color:app.ink;textFormat: Text.PlainText; text: "下载源"; font.pixelSize: 20 }
            AppSelect { model: ["自动（国内优先）", "国内源", "官方源"]; currentIndex: downloadSources.mode; onActivated: downloadSources.mode = currentIndex; Layout.fillWidth: true }
            AppLabel { color:app.ink;textFormat: Text.PlainText; text: "Minecraft 账号"; font.pixelSize: 20 }
            Repeater { model: desktop.accounts; delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                MD.RadioButton { text: modelData.name + " · " + modelData.type; selected: modelData.selected; onSelectionRequested: desktop.selectAccount(modelData.uuid); Layout.fillWidth: true }
                AppTextField { visible: modelData.type!=="正版登录" && modelData.type!=="离线登录"; text: modelData.type; placeholderText: "登录站点名称"; Layout.preferredWidth: 140; onEditingFinished: desktop.setAccountLabel(modelData.uuid,text) }
            } }
            RowLayout { Layout.fillWidth: true
                AppTextField { id: offlineName;objectName:"offlinePlayerName"; placeholderText: "离线玩家名"; Layout.fillWidth: true }
                ActionButton { text: "添加"; onClicked: { desktop.addOfflineAccount(offlineName.text); offlineName.clear() } }
            }
            AppLabel { color:app.ink;textFormat: Text.PlainText; text: desktop.error; visible: text.length > 0; wrapMode: Text.Wrap; Layout.fillWidth: true }
            RowLayout {
                ActionButton { text: "正版登录 / 管理"; onClicked: desktop.action("actionManageAccounts") }
                ActionButton { text: "第三方登录"; onClicked: thirdParty.open() }
            }
            ColumnLayout {
                visible: communityClient.authenticated; Layout.fillWidth: true;spacing:16
                AppLabel { color:app.ink;textFormat: Text.PlainText; text: "个人资料"; font.pixelSize: 20 }
                AppTextField { id: username; text: communityClient.profile.username || ""; placeholderText: "用户名"; Layout.fillWidth: true }
                MD.Pane {Layout.fillWidth:true;implicitHeight:120;radius:12;backgroundColor:app.colors.surfaceContainerHighest;TextArea { id: bio; anchors.fill:parent;anchors.margins:12;text: communityClient.profile.bio || ""; placeholderText: "简介";placeholderTextColor:app.muted; wrapMode: TextEdit.Wrap;color:app.ink;font:desktop.interfaceFont;background:null;selectByMouse:true }}
                RowLayout {
                    ActionButton { text: "保存"; onClicked: communityClient.updateProfile(username.text,bio.text) }
                    ActionButton { text: "更换头像"; onClicked: { var file = desktop.chooseFile("图片 (*.png *.jpg *.jpeg *.webp)"); if (String(file)) communityClient.uploadAvatar(file) } }
                }
            }
            RowLayout {
                spacing:4
                ActionButton { text: "启动器高级设置"; flat: true; onClicked: desktop.action("actionSettings") }
                ActionButton { text: "启动器日志"; flat: true; onClicked: desktop.action("actionViewLog") }
                ActionButton { text: "关于"; flat: true; onClicked: desktop.action("actionAbout") }
            }
            AppLabel {color:app.ink;text:"应用更新";font.pixelSize:20}
            AppLabel {color:app.muted;text:"DeeraftApp "+appUpdater.version+" · Prism 11.1.1"}
            RowLayout {Layout.fillWidth:true;AppLabel {text:"自动检查更新";color:app.ink;Layout.fillWidth:true}MD.Switch {checked:appUpdater.automatic;onCheckedChangeRequested:function(value){appUpdater.automatic=value}}}
            AppLabel {color:app.muted;text:appUpdater.status;visible:!!text;Layout.fillWidth:true;wrapMode:Text.Wrap}
            RowLayout {
                ActionButton {text:"检查更新";enabled:!appUpdater.busy;onClicked:appUpdater.check()}
                ActionButton {text:"下载更新";visible:appUpdater.available&&!appUpdater.ready;enabled:!appUpdater.busy;onClicked:appUpdater.download()}
                ActionButton {text:"重启并安装";visible:appUpdater.ready;highlighted:true;onClicked:appUpdater.install(app.allInstances.some(function(row){return row.running}))}
                ActionButton {text:"取消";visible:appUpdater.busy;onClicked:appUpdater.cancel()}
            }
        }
    }
    AppDialog {
        id: thirdParty; width: Math.min(dialog.width - 20, 550); height: Math.min(dialog.height - 20, 600); title: "第三方登录"; modal: true; standardButtons: Dialog.Close
        onClosed: externalAccounts.cancel()
        ScrollView { id:thirdPartyScroll;anchors.fill: parent; contentWidth: availableWidth;contentHeight:thirdPartyContent.implicitHeight
            ColumnLayout { id:thirdPartyContent;width: thirdPartyScroll.availableWidth; spacing: 12
                AppSelect { id: provider; model: ["Authlib-injector", "Yggdrasil Connect"]; Layout.fillWidth: true }
                AppTextField { id: server; placeholderText: "Yggdrasil API 地址（HTTPS）"; Layout.fillWidth: true }
                AppTextField { id: user; visible: provider.currentIndex === 0; placeholderText: "账号"; Layout.fillWidth: true }
                AppTextField { id: pass; visible: provider.currentIndex === 0; placeholderText: "密码"; echoMode: TextInput.Password; Layout.fillWidth: true }
                AppTextField { id: discovery; visible: provider.currentIndex === 1; placeholderText: "OpenID 发现地址"; Layout.fillWidth: true }
                AppTextField { id: clientId; visible: provider.currentIndex === 1; placeholderText: "Client ID"; Layout.fillWidth: true }
                ActionButton { text: "登录"; highlighted: true; enabled: !externalAccounts.busy; onClicked: { if (provider.currentIndex === 0) { externalAccounts.loginAuthlib(server.text,user.text,pass.text); pass.clear() } else externalAccounts.startConnect(discovery.text,clientId.text,server.text) } }
                BusyIndicator { running: externalAccounts.busy; visible: running }
                AppLabel { color:app.ink;textFormat: Text.PlainText; text: externalAccounts.deviceCode; visible: text.length > 0; font.pixelSize: 30 }
                ActionButton { text: "打开授权页面"; visible: externalAccounts.verificationUri.length > 0; onClicked: externalAccounts.openVerificationPage() }
                AppLabel { color:app.ink;textFormat: Text.PlainText; text: externalAccounts.error; visible: text.length > 0; wrapMode: Text.Wrap; Layout.fillWidth: true }
                Repeater { model: externalAccounts.profiles; delegate: ActionButton { required property var modelData; text: modelData.name; onClicked: externalAccounts.selectProfile(modelData.id) } }
            }
        }
    }
}
