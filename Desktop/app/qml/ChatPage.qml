import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
 id:page;required property var app
 property bool searchOpen:false
 property var messages:[]
 property string previousMessages:""
 property var filtered:messages.filter(function(row){return !query.text || String((row.player||row.sender||"")+" "+(row.message||row.content||"")).toLowerCase().indexOf(query.text.toLowerCase())>=0})
 function syncMessages(){var incoming=communityClient.chat;var key=JSON.stringify(incoming);if(key===previousMessages)return;previousMessages=key;var offset=list.contentY;messages=incoming;Qt.callLater(function(){if(list.follow)list.positionViewAtEnd();else list.contentY=Math.max(0,Math.min(offset,list.contentHeight-list.height))})}
 Component.onCompleted:syncMessages()
 Connections {target:communityClient;function onChanged(){page.syncMessages()}}
 RowLayout {anchors.fill:parent;anchors.leftMargin:8;anchors.rightMargin:32;anchors.bottomMargin:24;spacing:24
  Rectangle {Layout.fillWidth:true;Layout.fillHeight:true;color:app.panel;radius:28
   ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:16
    RowLayout {Layout.fillWidth:true;AppIcon {name:"grass";color:app.accent;font.pixelSize:32}ColumnLayout {Layout.fillWidth:true;Label {textFormat:Text.PlainText;text:"Minecraft";font.pixelSize:22;color:app.ink}Label {textFormat:Text.PlainText;text:app.clean((communityClient.community.mc||{}).motd);color:app.muted;font.pixelSize:13}}IconButton {symbol:"search";hint:"搜索消息";onClicked:page.searchOpen=!page.searchOpen}}
    TextField {id:query;visible:page.searchOpen;placeholderText:"搜索聊天记录";Layout.fillWidth:true}
    ListView {id:list;Layout.fillWidth:true;Layout.fillHeight:true;model:page.filtered;clip:true;spacing:20
     property bool follow:true
     onMovementStarted:follow=false
     delegate:RowLayout {required property var modelData;width:list.width;spacing:12
      Image {source:modelData.player?"https://mc-heads.net/avatar/"+encodeURIComponent(String(modelData.player))+"/48":"";Layout.preferredWidth:40;Layout.preferredHeight:40;Layout.alignment:Qt.AlignTop;asynchronous:true;smooth:false}
      ColumnLayout {Layout.fillWidth:true;spacing:6
       RowLayout {Layout.fillWidth:true;Label {textFormat:Text.PlainText;text:modelData.player||modelData.sender||"Minecraft";color:app.accent;font.weight:Font.Medium;Layout.fillWidth:true;elide:Text.ElideRight}Label {textFormat:Text.PlainText;text:String(modelData.time||"");color:app.muted;font.pixelSize:12}}
       TextEdit {text:String(modelData.message||modelData.content||"");textFormat:TextEdit.PlainText;color:app.ink;readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap;Layout.fillWidth:true;font.pixelSize:15}
      }
     }
     Label {textFormat:Text.PlainText;visible:!list.count;anchors.centerIn:parent;text:query.text?"没有匹配的消息":communityClient.authenticated?"暂无聊天消息":"登录后查看聊天";color:app.muted}
     ScrollBar.vertical:ScrollBar {}
    }
    RowLayout {Layout.fillWidth:true;Label {textFormat:Text.PlainText;text:"最近的消息";color:app.muted;font.pixelSize:12;Layout.fillWidth:true}ActionButton {text:"跳到最新";flat:true;onClicked:{list.follow=true;list.positionViewAtEnd()}}}
   }
  }
  Rectangle {Layout.preferredWidth:page.width<1050?220:280;Layout.fillHeight:true;color:app.panel;radius:28
   ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:20
    Label {textFormat:Text.PlainText;text:"在线玩家";font.pixelSize:20;color:app.ink}
    ListView {Layout.fillWidth:true;Layout.fillHeight:true;model:(communityClient.community.mc||{}).human_players||[];clip:true;spacing:16
     delegate:RowLayout {required property var modelData;width:ListView.view.width;spacing:12
      Image {source:"https://mc-heads.net/avatar/"+encodeURIComponent(String(modelData))+"/40";Layout.preferredWidth:36;Layout.preferredHeight:36;smooth:false;asynchronous:true}
      Label {textFormat:Text.PlainText;text:String(modelData);color:app.ink;Layout.fillWidth:true;elide:Text.ElideRight;font.pixelSize:13}
     }
    }
   }
  }
 }
}
