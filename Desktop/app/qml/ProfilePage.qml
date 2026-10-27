import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ScrollView {
 id:page;required property var app;clip:true;contentWidth:availableWidth
 property var ranking:communityClient.playtime.slice().sort(function(a,b){return Number(b.playtime_minutes||0)-Number(a.playtime_minutes||0)}).slice(0,5)
 RowLayout {width:page.availableWidth-56;x:24;spacing:24
  ColumnLayout {Layout.fillWidth:true;Layout.preferredWidth:1.6;Layout.alignment:Qt.AlignTop;spacing:24
   RowLayout {Layout.fillWidth:true;spacing:20
    Rectangle {Layout.preferredWidth:80;Layout.preferredHeight:80;color:app.colors.secondaryContainer;radius:28
     Image {anchors.fill:parent;anchors.margins:6;source:communityClient.authenticated?communityClient.imageUrl(communityClient.profile.avatar_url||""):"";fillMode:Image.PreserveAspectFit;asynchronous:true;AppIcon {anchors.centerIn:parent;visible:parent.status!==Image.Ready;name:"person";font.pixelSize:42;color:app.accent}}
    }
    ColumnLayout {Layout.fillWidth:true;Label { textFormat: Text.PlainText;text:communityClient.authenticated?communityClient.profile.username||"":"登录";font.pixelSize:30;color:app.ink}Label { textFormat: Text.PlainText;text:communityClient.profile.bio||"";color:app.muted;wrapMode:Text.Wrap;Layout.fillWidth:true}}
    ActionButton {text:"编辑资料";symbol:"edit";visible:communityClient.authenticated;onClicked:app.showSettings()}
   }
   Rectangle {visible:!communityClient.authenticated;Layout.fillWidth:true;implicitHeight:loginContent.implicitHeight+48;color:app.panel;radius:28
    ColumnLayout {id:loginContent;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:24;spacing:16
     Label { textFormat: Text.PlainText;text:"社区账号";font.pixelSize:20;color:app.ink}
     TextField {id:username;placeholderText:"用户名";Layout.fillWidth:true}
     TextField {id:password;placeholderText:"密码";echoMode:TextInput.Password;Layout.fillWidth:true;onAccepted:{communityClient.login(username.text,password.text);password.clear()}}
     RowLayout {ActionButton {text:"登录";highlighted:true;enabled:!communityClient.busy;onClicked:{communityClient.login(username.text,password.text);password.clear()}}ActionButton {text:"注册";enabled:!communityClient.busy;onClicked:{communityClient.registerAccount(username.text,password.text);password.clear()}}ActionButton {text:"Microsoft";flat:true;onClicked:communityClient.startMicrosoftLogin()}}
     Label { textFormat: Text.PlainText;visible:!!communityClient.error;text:communityClient.error;color:app.colors.error;wrapMode:Text.Wrap;Layout.fillWidth:true}
    }
   }
   Rectangle {visible:communityClient.authenticated;Layout.fillWidth:true;implicitHeight:statsContent.implicitHeight+56;color:app.colors.primaryContainer;radius:28
    ColumnLayout {id:statsContent;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:28;spacing:24
     Label { textFormat: Text.PlainText;text:"累计游玩";color:app.colors.onPrimaryContainer}
     Label { textFormat: Text.PlainText;text:app.duration(communityClient.playtime.reduce(function(sum,row){return sum+Number(row.playtime_minutes||0)},0));font.pixelSize:52;color:app.colors.onPrimaryContainer}
     Repeater {model:page.ranking;ColumnLayout {required property var modelData;required property int index;Layout.fillWidth:true;spacing:8
      RowLayout {Layout.fillWidth:true;Label { textFormat: Text.PlainText;text:String(index+1);Layout.preferredWidth:24;color:app.colors.onPrimaryContainer}Label { textFormat: Text.PlainText;text:modelData.server_name||modelData.name||"";Layout.fillWidth:true;color:app.colors.onPrimaryContainer}Label { textFormat: Text.PlainText;text:app.duration(modelData.playtime_minutes);color:app.colors.onPrimaryContainer}}
      ProgressBar {value:Number(modelData.playtime_minutes||0)/Math.max(1,page.ranking.length?Number(page.ranking[0].playtime_minutes||0):1);Layout.fillWidth:true}
     }}
    }
   }
   RowLayout {Layout.fillWidth:true;visible:communityClient.authenticated
    ActionButton {visible:communityClient.profile.role==="admin";text:"用户管理";onClicked:{communityClient.loadUsers("");users.open()}}
    ActionButton {text:"退出登录";flat:true;onClicked:communityClient.logout()}
   }
  }
  ColumnLayout {Layout.fillWidth:true;Layout.preferredWidth:1;Layout.alignment:Qt.AlignTop;spacing:24
   Rectangle {Layout.fillWidth:true;implicitHeight:dailyContent.implicitHeight+48;color:app.panel;radius:28
    ColumnLayout {id:dailyContent;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:24;spacing:16
     Label { textFormat: Text.PlainText;text:"每日在线";font.pixelSize:20;color:app.ink}
     RowLayout {Layout.fillWidth:true;TextField {id:date;text:communityClient.dailyDate;placeholderText:"YYYY-MM-DD";Layout.fillWidth:true;onAccepted:communityClient.loadDaily(text)}ActionButton {text:"查看";flat:true;enabled:communityClient.authenticated;onClicked:communityClient.loadDaily(date.text)}}
     Repeater {model:communityClient.daily;RowLayout {required property var modelData;Layout.fillWidth:true
      Label { textFormat: Text.PlainText;text:modelData.player||modelData.player_name||modelData.name||"";Layout.fillWidth:true;color:app.ink}
      Label { textFormat: Text.PlainText;text:app.duration(modelData.playtime_minutes||modelData.minutes||0);color:app.muted;font.pixelSize:12}
     }}
     Label { textFormat: Text.PlainText;visible:!communityClient.daily.length;text:communityClient.authenticated?"暂无记录":"登录后查看";color:app.muted}
    }
   }
   Rectangle {Layout.fillWidth:true;implicitHeight:220;color:app.colors.tertiaryContainer;radius:28
    ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:16
     AppIcon {name:"verified_user";color:app.colors.onTertiaryContainer;font.pixelSize:28}
     Label { textFormat: Text.PlainText;text:"Minecraft 账号";font.pixelSize:18;color:app.colors.onTertiaryContainer}
     Label { textFormat: Text.PlainText;text:desktop.accounts.length?desktop.accounts.map(function(r){return r.name}).join("、"):"尚未添加";color:app.colors.onTertiaryContainer;wrapMode:Text.Wrap;Layout.fillWidth:true}
     ActionButton {text:"管理账号";onClicked:app.showSettings()}
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
                    Label { textFormat: Text.PlainText; text: modelData.username; Layout.fillWidth: true }
                    ComboBox { model: ["user", "admin"]; currentIndex: modelData.role === "admin" ? 1 : 0; onActivated: communityClient.setUserRole(modelData.id,currentText) }
                }
            }
        }
    }
}
