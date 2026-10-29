import QtQuick
import Qcm.Material as MD
import QtQuick.Controls
import QtQuick.Layouts
Item {
 id:page;objectName:"chatPage";required property var app
 property bool searchOpen:false
 onSearchOpenChanged:if(!searchOpen)query.searchText=""
 property var messages:[]
 property string previousMessages:""
 property var filtered:messages.filter(function(row){return !query.searchText || String((row.player||row.sender||"")+" "+(row.message||row.content||"")).toLowerCase().indexOf(query.searchText.toLowerCase())>=0})
 function syncMessages(){var incoming=communityClient.chat;var key=JSON.stringify(incoming);if(key===previousMessages)return;previousMessages=key;var offset=list.contentY;messages=incoming;Qt.callLater(function(){if(list.follow)list.positionViewAtEnd();else list.contentY=Math.max(0,Math.min(offset,list.contentHeight-list.height))})}
 Component.onCompleted:syncMessages()
 Connections {target:communityClient;function onChanged(){page.syncMessages()}}
 RowLayout {anchors.fill:parent;anchors.leftMargin:8;anchors.rightMargin:32;anchors.bottomMargin:24;spacing:24
  Rectangle {Layout.fillWidth:true;Layout.fillHeight:true;color:app.panel;radius:28
   ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:16
    Item {Layout.fillWidth:true;Layout.preferredHeight:56
     AppIcon {id:chatIcon;name:"grass";color:app.accent;font.pixelSize:32;anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter}
     ColumnLayout {anchors.left:chatIcon.right;anchors.leftMargin:12;anchors.right:chatSearch.left;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter;spacing:0
      AppLabel {text:"Minecraft";font.pixelSize:22;color:app.ink;Layout.fillWidth:true}
      AppLabel {text:app.clean((communityClient.community.mc||{}).motd);color:app.muted;font.pixelSize:13;Layout.fillWidth:true;elide:Text.ElideRight}
     }
     IconButton {id:chatSearch;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;symbol:"search";hint:"搜索消息";onClicked:page.searchOpen=!page.searchOpen}
    }
    MD.SearchBar {id:query;objectName:"chatSearchField";visible:page.searchOpen;placeholderText:"搜索聊天记录";Layout.preferredHeight:48;Layout.fillWidth:true}
    ListView {id:list;Layout.fillWidth:true;Layout.fillHeight:true;model:page.filtered;clip:true;spacing:20
     property bool follow:true
     onMovementStarted:follow=false
     delegate:RowLayout {required property var modelData;readonly property bool eventMessage:modelData.type==="join"||modelData.type==="leave";width:list.width;spacing:12
      AppLabel {visible:parent.eventMessage;Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter;color:app.muted;font.pixelSize:12;text:(modelData.player||modelData.sender||"")+" "+(modelData.type==="join"?"加入了游戏":"离开了游戏")+" · "+(modelData.time||"")}
      Image {visible:!parent.eventMessage;source:modelData.player?"https://minotar.net/avatar/"+encodeURIComponent(String(modelData.player))+"/48":"";Layout.preferredWidth:40;Layout.preferredHeight:40;Layout.alignment:Qt.AlignTop;asynchronous:true;smooth:false}
      ColumnLayout {visible:!parent.eventMessage;Layout.fillWidth:true;spacing:6
       RowLayout {Layout.fillWidth:true;AppLabel {textFormat:Text.PlainText;text:modelData.player||modelData.sender||"Minecraft";color:app.accent;font.weight:Font.Medium;Layout.alignment:Qt.AlignBaseline;Layout.fillWidth:true;elide:Text.ElideRight}AppLabel {textFormat:Text.PlainText;text:String(modelData.time||"");color:app.muted;font.pixelSize:12;Layout.alignment:Qt.AlignBaseline}}
       TextEdit {text:String(modelData.message||modelData.content||"");textFormat:TextEdit.PlainText;color:app.ink;readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap;Layout.fillWidth:true;font.pixelSize:15}
      }
     }
     AppLabel {textFormat:Text.PlainText;visible:!list.count;anchors.centerIn:parent;text:query.searchText?"没有匹配的消息":communityClient.authenticated?"暂无聊天消息":"登录后查看聊天";color:app.muted}
     ScrollBar.vertical:ScrollBar {}
    }
    RowLayout {Layout.fillWidth:true;AppLabel {textFormat:Text.PlainText;text:"最近的消息";color:app.muted;font.pixelSize:12;Layout.fillWidth:true}ActionButton {text:"跳到最新";flat:true;onClicked:{list.follow=true;list.positionViewAtEnd()}}}
   }
  }
  Rectangle {Layout.preferredWidth:page.width<1050?220:280;Layout.fillHeight:true;color:app.panel;radius:28
   ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:20
    AppLabel {textFormat:Text.PlainText;text:"在线玩家";font.pixelSize:20;color:app.ink}
    ListView {Layout.fillWidth:true;Layout.fillHeight:true;model:(communityClient.community.mc||{}).human_players||[];clip:true;spacing:16
     delegate:RowLayout {required property var modelData;width:ListView.view.width;spacing:12
      Image {source:"https://minotar.net/avatar/"+encodeURIComponent(String(modelData))+"/40";Layout.preferredWidth:36;Layout.preferredHeight:36;smooth:false;asynchronous:true}
      AppLabel {textFormat:Text.PlainText;text:String(modelData);color:app.ink;Layout.fillWidth:true;elide:Text.ElideRight;font.pixelSize:13}
     }
    }
   }
  }
 }
}
