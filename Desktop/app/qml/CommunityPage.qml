import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ScrollView {
 id:page
 required property var app
 property var mc:communityClient.community.mc||({})
 property var kook:communityClient.community.kook||({})
 property bool humans:true
 property bool expanded:false
 property string address:app.serverAddress("community",String(mc.address||"mc.ainfinitythecoder.cn"))
 clip:true;contentWidth:availableWidth
 RowLayout {
  width:page.availableWidth-40;x:8;spacing:24
  ColumnLayout {
   Layout.fillWidth:true;Layout.preferredWidth:2;Layout.alignment:Qt.AlignTop;spacing:24
   Rectangle {Layout.fillWidth:true;implicitHeight:330;radius:32;color:app.colors.primaryContainer
    RowLayout {anchors.fill:parent;anchors.margins:32;spacing:20
     ColumnLayout {Layout.fillWidth:true;spacing:12
      Label { textFormat: Text.PlainText;text:"●  Minecraft";color:app.colors.onPrimaryContainer;font.pixelSize:13}
      Label { textFormat: Text.PlainText;text:app.clean(page.mc.motd)||"Minecraft";color:app.colors.onPrimaryContainer;font.pixelSize:38;wrapMode:Text.Wrap;Layout.fillWidth:true;maximumLineCount:2;elide:Text.ElideRight}
      RowLayout {Label { textFormat: Text.PlainText;text:page.address;color:app.colors.onPrimaryContainer;font.pixelSize:12}IconButton {symbol:"content_copy";hint:"复制地址";onClicked:{addressCopy.text=page.address;addressCopy.selectAll();addressCopy.copy();app.notify("地址已复制")}}}
      RowLayout {spacing:28
       Column {Label { textFormat: Text.PlainText;text:page.mc.online_count!==undefined?String(page.mc.online_count):"—";font.pixelSize:36;color:app.colors.onPrimaryContainer}Label { textFormat: Text.PlainText;text:"在线";font.pixelSize:12;color:app.colors.onPrimaryContainer}}
       Column {Label { textFormat: Text.PlainText;text:page.mc.latency_ms!==undefined?Math.round(page.mc.latency_ms)+" ms":"—";font.pixelSize:30;color:app.colors.onPrimaryContainer}Label { textFormat: Text.PlainText;text:"延迟";font.pixelSize:12;color:app.colors.onPrimaryContainer}}
       Label { textFormat: Text.PlainText;text:page.mc.version||"";color:app.colors.onPrimaryContainer;Layout.maximumWidth:130;wrapMode:Text.Wrap;font.pixelSize:13}
      }
      Item {Layout.fillHeight:true}
      RowLayout {ActionButton {text:"启动并加入";symbol:"play_arrow";highlighted:true;onClicked:app.joinServer("community",page.address)}ActionButton {text:app.linkedName("community");symbol:"link";flat:true;onClicked:app.associate("community",page.address)}}
     }
     Rectangle {visible:page.width>1150;Layout.preferredWidth:160;Layout.preferredHeight:220;radius:80;color:app.colors.secondaryContainer;clip:true;AppIcon {anchors.centerIn:parent;name:"public";font.pixelSize:120;color:app.colors.onPrimaryContainer}}
    }
   }
   Rectangle {Layout.fillWidth:true;implicitHeight:playersContent.implicitHeight+48;radius:28;color:app.panel
    ColumnLayout {id:playersContent;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:24;spacing:20
     RowLayout {Layout.fillWidth:true;Label { textFormat: Text.PlainText;text:"在线玩家";color:app.ink;font.pixelSize:22;Layout.fillWidth:true}ActionButton {text:"真人";highlighted:page.humans;onClicked:page.humans=true}ActionButton {text:"全部";highlighted:!page.humans;onClicked:page.humans=false}}
     Flow {Layout.fillWidth:true;spacing:16;property var players:page.humans?(page.mc.human_players||[]):(page.mc.players||[])
      Repeater {model:page.expanded?parent.players:parent.players.slice(0,12);Column {required property var modelData;width:90;spacing:8
       Image {anchors.horizontalCenter:parent.horizontalCenter;width:56;height:56;source:"https://mc-heads.net/avatar/"+encodeURIComponent(String(modelData))+"/64";smooth:false;asynchronous:true}
       Label { textFormat: Text.PlainText;width:parent.width;text:String(modelData);elide:Text.ElideRight;horizontalAlignment:Text.AlignHCenter;color:app.ink;font.pixelSize:12}
      }}
     }
     Label { textFormat: Text.PlainText;visible:!(page.mc.players||[]).length;text:communityClient.authenticated?"暂无在线玩家":"登录后查看社区";color:app.muted}
     ActionButton {visible:(page.mc.players||[]).length>12;text:page.expanded?"收起":"展开";flat:true;onClicked:page.expanded=!page.expanded}
    }
   }
   RowLayout {Layout.fillWidth:true;spacing:24
    Rectangle {Layout.fillWidth:true;implicitHeight:180;radius:28;color:app.panel
     ColumnLayout {anchors.fill:parent;anchors.margins:24;Label { textFormat: Text.PlainText;text:"服务器";font.weight:Font.DemiBold;color:app.ink}Label { textFormat: Text.PlainText;text:communityClient.servers.length?communityClient.servers[0].name:"服务器管理";font.pixelSize:20;color:app.ink;elide:Text.ElideRight;Layout.fillWidth:true}ActionButton {text:"查看服务器";flat:true;onClicked:app.page=2}}
    }
    Rectangle {Layout.fillWidth:true;implicitHeight:180;radius:28;color:app.colors.tertiaryContainer
     ColumnLayout {anchors.fill:parent;anchors.margins:24
      RowLayout {Layout.fillWidth:true;Label { textFormat: Text.PlainText;text:"直播间";font.pixelSize:20;color:app.colors.onTertiaryContainer;Layout.fillWidth:true}IconButton {visible:communityClient.profile.role==="admin";symbol:"edit";hint:"管理直播间";onClicked:liveEditor.open()}}
      AppSelect {id:room;Layout.fillWidth:true;model:communityClient.liveRooms;textRole:"title";valueRole:"room_id"}
      ActionButton {text:"观看";symbol:"play_arrow";enabled:communityClient.liveRooms.length>0;onClicked:desktop.openLive(String(room.currentValue||communityClient.liveRooms[room.currentIndex].id))}
     }
    }
   }
  }
  ColumnLayout {Layout.fillWidth:true;Layout.preferredWidth:1;Layout.alignment:Qt.AlignTop;spacing:24
   Rectangle {Layout.fillWidth:true;implicitHeight:voiceContent.implicitHeight+48;color:app.panel;radius:28
    ColumnLayout {id:voiceContent;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:24;spacing:16
     Label { textFormat: Text.PlainText;text:"KOOK";font.pixelSize:20;color:app.ink}
     Repeater {model:page.kook.channels||[];ColumnLayout {required property var modelData;Layout.fillWidth:true;spacing:12
      RowLayout {Layout.fillWidth:true;AppIcon {name:"volume_up";color:app.muted;font.pixelSize:20}Label { textFormat: Text.PlainText;text:modelData.name||"语音频道";color:app.ink;Layout.fillWidth:true;font.pixelSize:14}Label { textFormat: Text.PlainText;text:String((modelData.users||[]).length);color:app.muted}}
      Repeater {model:modelData.users||[];RowLayout {required property var modelData;Layout.fillWidth:true;Layout.leftMargin:28
       Image {source:modelData.avatar||"";Layout.preferredWidth:28;Layout.preferredHeight:28;asynchronous:true}
       Label { textFormat: Text.PlainText;text:modelData.nickname||modelData.username||modelData.name||"";color:app.ink;Layout.fillWidth:true;elide:Text.ElideRight;font.pixelSize:13}
      }}
     }}
     Label { textFormat: Text.PlainText;visible:!(page.kook.channels||[]).length;text:"暂无语音频道";color:app.muted}
     ActionButton {text:"进入语音";symbol:"headphones";Layout.fillWidth:true;enabled:!!(page.kook.invite_url||page.kook.url);onClicked:Qt.openUrlExternally(page.kook.invite_url||page.kook.url)}
    }
   }
   AbstractButton {Layout.fillWidth:true;implicitHeight:86;onClicked:app.page=3
    background:Rectangle {radius:20;color:app.colors.secondaryContainer}
    contentItem:RowLayout {anchors.fill:parent;anchors.margins:20;AppIcon {name:"forum";color:app.colors.onSecondaryContainer}ColumnLayout {Layout.fillWidth:true;Label { textFormat: Text.PlainText;text:"社区聊天";color:app.colors.onSecondaryContainer}Label { textFormat: Text.PlainText;text:communityClient.chat.length?String(communityClient.chat[communityClient.chat.length-1].message||communityClient.chat[communityClient.chat.length-1].content||""):"查看聊天记录";color:app.colors.onSecondaryContainer;font.pixelSize:12;elide:Text.ElideRight;Layout.fillWidth:true}}AppIcon {name:"arrow_forward";color:app.colors.onSecondaryContainer}}
   }
   Rectangle {Layout.fillWidth:true;implicitHeight:activityContent.implicitHeight+40;color:app.panel;radius:24
    ColumnLayout {id:activityContent;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:20;spacing:16
     Label { textFormat: Text.PlainText;text:"玩家动态";color:app.ink;font.weight:Font.DemiBold}
     Repeater {model:app.activity.slice(0,5);Label { textFormat: Text.PlainText;required property var modelData;text:modelData.player+" 启动了 "+modelData.instance;color:app.muted;wrapMode:Text.Wrap;Layout.fillWidth:true;font.pixelSize:13}}
     Label { textFormat: Text.PlainText;visible:!app.activity.length;text:"暂无动态";color:app.muted}
    }
   }
  }
 }
 TextEdit {id:addressCopy;visible:false}
    AppDialog {
        id: liveEditor; title: "直播间"; anchors.centerIn: parent; width: Math.min(page.width - 40, 580); modal: true
        standardButtons: Dialog.Save | Dialog.Cancel
        onOpened: liveJson.text = JSON.stringify(communityClient.liveRooms, null, 2)
        onAccepted: { try { communityClient.saveLiveRooms(JSON.parse(liveJson.text)) } catch(e) { liveJson.text = String(e) } }
        TextArea { id: liveJson; width: parent.width; height: 300; wrapMode: TextEdit.Wrap; selectByMouse: true }
    }
}
