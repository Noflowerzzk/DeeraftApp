import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qcm.Material as MD
ScrollView {
 id: page
 required property var app
 clip: true
 contentWidth: availableWidth
 property var ranking: communityClient.playtime.slice().sort(function(a,b){return Number(b.playtime_minutes||0)-Number(a.playtime_minutes||0)}).slice(0,5)
 property real totalMinutes: communityClient.playtime.reduce(function(sum,row){return sum+Number(row.playtime_minutes||0)},0)
 property real weekMax: Math.max(1,...communityClient.dailyWeek.map(function(day){return Number(day.minutes||0)}))
 function refreshWeek(){if(visible && communityClient.authenticated)communityClient.loadDailyWeek(communityClient.dailyDate)}
 onVisibleChanged: refreshWeek()
 Component.onCompleted: refreshWeek()
 Connections { target: communityClient; function onChanged(){page.refreshWeek()} }
 RowLayout {
  width: page.availableWidth-(app.width>=1600?64:56)
  x: 24
  spacing: 24
  ColumnLayout {
   Layout.preferredWidth: (parent.width-24)*1.6/2.6
   Layout.minimumWidth: 0
   Layout.maximumWidth: (parent.width-24)*1.6/2.6
   Layout.alignment: Qt.AlignTop
   spacing: 24
   RowLayout {
    Layout.fillWidth: true
    Layout.topMargin: 16
    Layout.bottomMargin: 24
    spacing: 20
    RoundedImage { Layout.preferredWidth: 88; Layout.preferredHeight: 88; radius: 28; source: app.gameAccount?app.gameAccount.avatar:""; MD.Icon { visible: !app.gameAccount; anchors.centerIn: parent; name: "person"; size: 48; color: app.accent } }
    ColumnLayout { Layout.fillWidth: true; spacing: 10; AppLabel { text: communityClient.authenticated?communityClient.profile.username||"":"登录"; font.pixelSize: 32; lineHeight: 42; color: app.ink; Layout.fillWidth: true; elide: Text.ElideRight } AppLabel { text: communityClient.profile.bio||""; color: app.muted; font.pixelSize: 14; wrapMode: Text.Wrap; Layout.fillWidth: true } }
    ActionButton { text: "编辑资料"; symbol: "edit"; visible: communityClient.authenticated; onClicked: app.showSettings() }
   }
   MD.Pane {
    visible: !communityClient.authenticated
    Layout.fillWidth: true
    implicitHeight: loginContent.implicitHeight+48
    radius: 28; backgroundColor: app.panel
    ColumnLayout {
     id: loginContent
     anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 24
     spacing: 20
     AppLabel { text: "社区账号"; font.pixelSize: 20; color: app.ink }
     AppTextField { id: username; placeholderText: "用户名"; Layout.fillWidth: true }
     AppTextField { id: password; placeholderText: "密码"; echoMode: TextInput.Password; Layout.fillWidth: true; onAccepted: {communityClient.login(username.text,password.text);password.clear()} }
     RowLayout {
      spacing: 12
      ActionButton { text: "登录"; highlighted: true; enabled: !communityClient.busy; onClicked: {communityClient.login(username.text,password.text);password.clear()} }
      ActionButton { text: "注册"; enabled: !communityClient.busy; onClicked: {communityClient.registerAccount(username.text,password.text);password.clear()} }
      ActionButton { text: "Microsoft"; flat: true; onClicked: communityClient.startMicrosoftLogin() }
     }
     AppLabel { visible: !!communityClient.error; text: communityClient.error; color: app.colors.error; wrapMode: Text.Wrap; Layout.fillWidth: true }
    }
   }
   MD.Pane {
    visible: communityClient.authenticated
    Layout.fillWidth: true
    implicitHeight: statsContent.implicitHeight+64
    radius: 32; backgroundColor: app.colors.primaryContainer
    ColumnLayout {
     id: statsContent
     anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 32
     spacing: 0
     RowLayout { Layout.fillWidth: true; AppLabel { text: "累计游玩"; color: app.colors.onPrimaryContainer; font.weight: 600; Layout.fillWidth: true } MD.Icon { name: "sports_esports"; size: 28; color: app.colors.onPrimaryContainer } }
     RowLayout { Layout.topMargin: 20; Layout.bottomMargin: 32; spacing: 12; AppLabel { text: (page.totalMinutes/60).toFixed(1); font.pixelSize: 72; lineHeight: 94; font.weight: 600; font.letterSpacing: -2; color: app.colors.onPrimaryContainer } AppLabel { text: "小时"; font.pixelSize: 20; color: app.colors.onPrimaryContainer; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 18 } }
     ColumnLayout {
      Layout.fillWidth: true
      spacing: 24
      Repeater {
       model: page.ranking
       RowLayout {
        required property var modelData
        required property int index
        Layout.fillWidth: true
        spacing: 16
        AppLabel { text: index+1; color: app.colors.onPrimaryContainer; Layout.preferredWidth: 18; font.pixelSize: 14 }
        ColumnLayout {
         Layout.fillWidth: true
         spacing: 8
         RowLayout { Layout.fillWidth: true; AppLabel { text: modelData.server_name||modelData.name||""; color: app.colors.onPrimaryContainer; font.pixelSize: 14; Layout.fillWidth: true; elide: Text.ElideRight } AppLabel { text: app.duration(modelData.playtime_minutes); color: app.colors.onPrimaryContainer; font.pixelSize: 13 } }
         MD.LinearIndicator { Layout.fillWidth: true; Layout.preferredHeight: 6; indeterminate: false; completionBehavior: MD.LinearIndicator.Keep; value: Number(modelData.playtime_minutes||0)/Math.max(1,Number(page.ranking[0].playtime_minutes||0)); wavy: false; strokeWidth: 6; stopIndicatorColor: "transparent"; color: app.accent; trackColor: app.colors.secondaryContainer; animationsEnabled: !library.reducedMotion }
        }
       }
      }
      AppLabel { visible: !page.ranking.length; text: "暂无游玩记录"; color: app.colors.onPrimaryContainer }
     }
    }
   }
   RowLayout { visible: communityClient.authenticated; Layout.fillWidth: true; ActionButton { text: "用户管理"; visible: communityClient.profile.role==="admin"; onClicked: {communityClient.loadUsers("");users.open()} } ActionButton { text: "退出登录"; flat: true; onClicked: communityClient.logout() } }
  }
  ColumnLayout {
   Layout.fillWidth: true
   Layout.alignment: Qt.AlignTop
   spacing: 24
   MD.Pane {
    Layout.fillWidth: true
    implicitHeight: dailyContent.implicitHeight+48
    radius: 28; backgroundColor: app.panel
    ColumnLayout {
     id: dailyContent
     anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 24
     spacing: 0
     RowLayout {
      Layout.fillWidth: true
      AppLabel { text: "每日在线"; color: app.ink; font.pixelSize: 18; font.weight: 600; Layout.fillWidth: true }
      ActionButton { text: communityClient.dailyDate.slice(5).replace("-"," 月 ")+" 日"; symbol: "calendar_today"; flat: true; font.pixelSize: 13; enabled: communityClient.authenticated; onClicked: calendar.open() }
     }
     RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 180
      Layout.topMargin: 30
      Layout.bottomMargin: 12
      spacing: 12
      Repeater {
       model: communityClient.dailyWeek
       MD.Button {
        id: dayControl
        required property var modelData
        required property int index
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
        flat: true; mdState.type: MD.Enum.BtText
        onClicked: communityClient.loadDaily(modelData.date)
        contentItem: Item {
         MD.ElevationRectangle {
          width: parent.width
          height: dayControl.modelData.available ? Math.max(8,Math.min(152,Number(dayControl.modelData.minutes||0)/page.weekMax*152)) : 8
          anchors.bottom: weekday.top; anchors.bottomMargin: 12
          radius: width/2
          color: dayControl.modelData.date===communityClient.dailyDate?app.accent:app.colors.secondaryContainer
          opacity: dayControl.modelData.available?1:.35
          Behavior on height { enabled: !library.reducedMotion; NumberAnimation { duration: 500; easing: MD.Token.easing.emphasized } }
         }
         AppLabel { id: weekday; anchors.bottom: parent.bottom; width: parent.width; text: ["一","二","三","四","五","六","日"][dayControl.index]; color: app.muted; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter }
        }
        MD.ToolTip.text: modelData.available?app.duration(modelData.minutes):"暂无记录"
        MD.ToolTip.visible: dayControl.mdState.interactions.hovered
       }
      }
      AppLabel { visible: !communityClient.dailyWeek.length; text: communityClient.authenticated?"正在加载":"登录后查看"; color: app.muted; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
     }
     Repeater {
      model: communityClient.daily
      RowLayout {
       required property var modelData
       Layout.fillWidth: true
       Layout.topMargin: 24
       spacing: 9
       RoundedImage { Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 10; source: "https://minotar.net/avatar/"+encodeURIComponent(modelData.player||modelData.player_name||modelData.name||"")+"/40" }
       AppLabel { text: modelData.player||modelData.player_name||modelData.name||""; color: app.ink; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
       AppLabel { text: app.duration(modelData.playtime_minutes||modelData.minutes||0); color: app.ink; font.pixelSize: 13 }
      }
     }
     AppLabel { visible: communityClient.authenticated && !communityClient.daily.length; text: "暂无记录"; color: app.muted; Layout.topMargin: 24 }
    }
   }
   MD.Pane {
    Layout.fillWidth: true
    Layout.preferredHeight: 264
    radius: 28; backgroundColor: app.colors.tertiaryContainer
    ColumnLayout {
     anchors.fill: parent; anchors.margins: 24
     spacing: 16
     MD.Icon { name: "verified_user"; size: 28; color: app.colors.onTertiaryContainer }
     AppLabel { text: "Minecraft 账号"; color: app.colors.onTertiaryContainer; font.pixelSize: 16 }
     ColumnLayout { Layout.fillWidth: true; spacing: 2; AppLabel { text: desktop.accounts.length?desktop.accounts.map(function(a){return a.name}).join("、"):"尚未添加"; color: app.colors.onTertiaryContainer; font.pixelSize: 18; Layout.fillWidth: true; elide: Text.ElideRight } AppLabel { text: (desktop.accounts.find(function(a){return a.selected})||{}).type||""; color: app.colors.onTertiaryContainer; font.pixelSize: 13 } }
     Item { Layout.fillHeight: true }
     ActionButton { text: "管理账号"; onClicked: app.showSettings() }
    }
   }
  }
 }
 MD.DatePickerDialog { id: calendar; objectName: "dailyCalendar"; parent: appRoot; locale: Qt.locale("zh_CN"); selectedDate: new Date(communityClient.dailyDate+"T12:00:00"); onAcceptedDate: function(date){communityClient.loadDaily(Qt.formatDate(date,"yyyy-MM-dd"));communityClient.loadDailyWeek(Qt.formatDate(date,"yyyy-MM-dd"))} }
    AppDialog {
        id: users; width: Math.min(page.width - 40, 700); height: Math.min(page.height - 40, 600); title: "用户管理"; modal: true; standardButtons: Dialog.Close
        ColumnLayout { anchors.fill: parent
            AppTextField { placeholderText: "搜索用户名"; Layout.fillWidth: true; onAccepted: communityClient.loadUsers(text) }
            ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: communityClient.users; clip: true
                delegate: RowLayout { required property var modelData; width: ListView.view.width
                    AppLabel { textFormat: Text.PlainText; text: modelData.username; Layout.fillWidth: true }
                    AppSelect { model: ["user", "admin"]; currentIndex: modelData.role === "admin" ? 1 : 0; onActivated: communityClient.setUserRole(modelData.id,currentText) }
                }
            }
        }
    }
}
