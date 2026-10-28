import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qcm.Material as MD
ScrollView {
 id: page
 objectName:"communityPage"
 required property var app
 property var mc: communityClient.community.mc||({})
 property var kook: communityClient.community.kook||({})
 property var streamingRooms: communityClient.liveRooms.filter(function(room){return !!room.live})
 property bool humans: true
 property bool expanded: false
 property string address: app.serverAddress("community",String(mc.address||"mc.ainfinitythecoder.cn"))
 property var players: humans ? (mc.human_players||[]) : (mc.players||[])
 property int voiceCount: (kook.channels||[]).reduce(function(sum,ch){return sum+(ch.users||[]).length},0)
 clip: true
 implicitHeight:0
 Layout.minimumHeight:0
 Layout.fillHeight:true
 Layout.fillWidth:true
 contentWidth: availableWidth
 contentHeight: communityColumns.implicitHeight+32
 Component.onCompleted:{contentItem.boundsBehavior=Flickable.StopAtBounds;contentItem.boundsMovement=Flickable.StopAtBounds}
 RowLayout {
  id: communityColumns
  width: page.availableWidth-(app.width>=1600?64:56)
  x: 8
  spacing: app.width<=1250?16:24
  ColumnLayout {
   Layout.preferredWidth: (parent.width-parent.spacing)*1.85/2.85
   Layout.minimumWidth: 0
   Layout.maximumWidth: (parent.width-parent.spacing)*1.85/2.85
   Layout.alignment: Qt.AlignTop
   spacing: 24
   MD.Pane {
    id: serverHero
    objectName: "serverHero"
    clip: true
    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(342,heroCopy.implicitHeight+64)
    corners: MD.Util.corners(48,28,28,28)
    backgroundColor: app.colors.primaryContainer
    RowLayout {
     anchors.fill: parent
     anchors.margins: app.width<=1250?28:32
     spacing: 20
     ColumnLayout {
      id: heroCopy
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      spacing: 0
      AppLabel { text: "●  Minecraft"; color: app.colors.onPrimaryContainer; font.pixelSize: 14; font.weight: 550 }
      AppLabel { objectName: "motdText"; text: app.clean(page.mc.motd)||"Minecraft"; color: app.colors.onPrimaryContainer; font.pixelSize: app.clean(page.mc.motd).length>28?32:app.width<=1050?38:45; lineHeight: font.pixelSize*1.3; font.weight: 650; font.letterSpacing: -1; Layout.fillWidth: true; Layout.topMargin: 10; Layout.bottomMargin: 6; Layout.minimumWidth: 0; maximumLineCount: 2; wrapMode: Text.WrapAnywhere; elide: Text.ElideRight }
      RowLayout {
       spacing: 4
       AppLabel { text: page.address; color: app.colors.onPrimaryContainer; font.pixelSize: 13 }
       IconButton { symbol: "content_copy"; hint: "复制地址"; implicitWidth: 32; implicitHeight: 32; onClicked: {addressCopy.text=page.address;addressCopy.selectAll();addressCopy.copy();app.notify("地址已复制")} }
      }
      RowLayout {
       spacing: 32
       Layout.topMargin: 16
       Layout.bottomMargin: 24
       Column { AppLabel { text: page.mc.online_count!==undefined?String(page.mc.online_count):"—"; color: app.colors.onPrimaryContainer; font.pixelSize: 36; lineHeight: 47; font.weight: 600 } AppLabel { text: "在线"; color: app.colors.onPrimaryContainer; font.pixelSize: 13 } }
       Column {
        Row { AppLabel { text: page.mc.latency_ms!==undefined?Math.round(page.mc.latency_ms):"—"; color: app.colors.onPrimaryContainer; font.pixelSize: 36; lineHeight: 47; font.weight: 600 } AppLabel { text: " ms"; color: app.colors.onPrimaryContainer; font.pixelSize: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 6 } }
        AppLabel { text: "延迟"; color: app.colors.onPrimaryContainer; font.pixelSize: 13 }
       }
       Column { visible: !!page.mc.version; AppLabel { text: app.clean(page.mc.version).split(" ").slice(0,-1).join(" ")||app.clean(page.mc.version); color: app.colors.onPrimaryContainer; font.pixelSize: 20; lineHeight: 36 } AppLabel { text: app.clean(page.mc.version).split(" ").length>1?app.clean(page.mc.version).split(" ").slice(-1)[0]:""; color: app.colors.onPrimaryContainer; font.pixelSize: 13 } }
      }
      RowLayout {
       spacing: 12
       ActionButton { objectName: "heroLaunchButton"; text: "启动并加入"; symbol: "play_arrow"; highlighted: true; onClicked: app.joinServer("community",page.address) }
       ActionButton { text: app.linkedName("community"); symbol: "link"; flat: true; onClicked: app.associate("community",page.address) }
      }
     }
     RoundedImage {
      visible: app.width>1050
      Layout.preferredWidth: app.width<=1250?130:195
      Layout.preferredHeight: app.width<=1250?220:244
      corners: MD.Util.corners(100,100,24,24)
      source: "qrc:/deeraft/images/map.png"
      rotation: 4
     }
    }
   }
   MD.Pane {
    Layout.fillWidth: true
    implicitHeight: playersContent.implicitHeight+48
    radius: 28
    backgroundColor: app.panel
    ColumnLayout {
     id: playersContent
     anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 24
     spacing: 24
     RowLayout {
      Layout.fillWidth: true
      AppLabel { text: "在线玩家"; color: app.ink; font.pixelSize: 20; font.weight: 600; Layout.fillWidth: true }
      MD.ButtonGroupContainer {
       variant: MD.ButtonGroupContainer.Connected; animateWidth: false; size: MD.Enum.S
       MD.ToggleButton { implicitHeight: 36; leftPadding: 14; rightPadding: 14; font.pixelSize: 13; text: "真人"; checked: page.humans; icon.name: checked?"check":""; mdState.type: MD.Enum.BtFilledTonal; onCheckedChangeRequested: page.humans=true }
       MD.ToggleButton { implicitHeight: 36; leftPadding: 14; rightPadding: 14; font.pixelSize: 13; text: "全部"; checked: !page.humans; icon.name: checked?"check":""; mdState.type: MD.Enum.BtFilledTonal; onCheckedChangeRequested: page.humans=false }
      }
     }
     GridLayout {
      Layout.fillWidth: true
      columns: app.width<=1050?3:5
      Layout.topMargin: 8; Layout.bottomMargin: 8
      columnSpacing: 12
      rowSpacing: 24
      Repeater {
       model: page.expanded?page.players:page.players.slice(0,10)
       ColumnLayout {
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 10
        RoundedImage { Layout.preferredWidth: 56; Layout.preferredHeight: 56; Layout.alignment: Qt.AlignHCenter; radius: 16; source: "https://minotar.net/avatar/"+encodeURIComponent(String(modelData))+"/64" }
        AppLabel { text: String(modelData); font.pixelSize: 13; color: app.ink; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
       }
      }
     }
     AppLabel { visible: !page.players.length; text: communityClient.authenticated?"暂无在线玩家":"登录后查看社区"; color: app.muted }
     ActionButton { visible: page.players.length>10; text: page.expanded?"收起":"展开"; flat: true; onClicked: page.expanded=!page.expanded }
    }
   }
   RowLayout {
    Layout.fillWidth: true
    spacing: 24
    MD.Pane {
     Layout.fillWidth: true
     Layout.preferredWidth: 1
     Layout.preferredHeight: 196
     radius: 28; backgroundColor: app.panel
     ColumnLayout {
      anchors.fill: parent; anchors.margins: 24; spacing: 8
      RowLayout { Layout.fillWidth: true; AppLabel { text: "服务器"; font.pixelSize: 16; font.weight: 600; color: app.ink; Layout.fillWidth: true } MD.Icon { name: "dns"; size: 24; color: app.ink } }
      AppLabel { text: communityClient.servers.length?communityClient.servers[0].name:"服务器管理"; font.pixelSize: 22; color: app.ink; Layout.fillWidth: true; elide: Text.ElideRight }
      AppLabel { text: communityClient.servers.length?String(communityClient.servers[0].version||communityClient.servers[0].description||""):""; color: app.muted; font.pixelSize: 13 }
      Item { Layout.fillHeight: true }
      ActionButton { text: "查看服务器 ↗"; flat: true; onClicked: app.page=2 }
     }
    }
    MD.Pane {
     Layout.fillWidth: true
     Layout.preferredWidth: 1
     Layout.preferredHeight: 196
     radius: 28; backgroundColor: app.colors.tertiaryContainer
     ColumnLayout {
      anchors.fill: parent; anchors.margins: 24; spacing: 12
      RowLayout { Layout.fillWidth: true; AppLabel { text: "直播"; font.pixelSize: 20; color: app.colors.onTertiaryContainer; Layout.fillWidth: true } MD.Icon { name: "smart_display"; size: 32; color: app.colors.onTertiaryContainer } }
      Repeater { model: page.streamingRooms
       AppLabel { required property var modelData; Layout.fillWidth: true; elide: Text.ElideRight; color: app.colors.onTertiaryContainer; text: modelData.name||modelData.title||"直播间" }
      }
      AppLabel { visible: !page.streamingRooms.length; text: communityClient.liveRooms.some(function(room){return !room.checked&&!room.statusError})?"查询中":communityClient.liveRooms.some(function(room){return room.statusError})?"状态暂不可用":"暂无直播"; color: app.colors.onTertiaryContainer }

     }
    }
   }
  }
  ColumnLayout {
   Layout.fillWidth: true
   Layout.alignment: Qt.AlignTop
   spacing: 24
   MD.Pane {
    Layout.fillWidth: true
    implicitHeight: voiceContent.implicitHeight+48
    radius: 28; backgroundColor: app.panel
    ColumnLayout {
     id: voiceContent
     anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 24
     spacing: 16
     RowLayout { Layout.fillWidth: true; AppLabel { text: "KOOK"; font.pixelSize: 20; color: app.ink; Layout.fillWidth: true } AppLabel { text: page.voiceCount+" 人在线"; color: app.muted; font.pixelSize: 13 } }
     Repeater {
      model: page.kook.channels||[]
      ColumnLayout {
       required property var modelData
       Layout.fillWidth: true
       spacing: 12
       Layout.topMargin: 8; Layout.bottomMargin: 0
       RowLayout { Layout.fillWidth: true; spacing: 12; MD.Icon { name: "volume_up"; size: 20; color: app.muted } AppLabel { text: modelData.name||"语音频道"; color: app.ink; font.weight: 550; Layout.fillWidth: true } AppLabel { text: (modelData.users||[]).length; font.pixelSize: 13; color: app.muted } }
       Repeater {
        model: modelData.users||[]
        RowLayout {
         required property var modelData
         Layout.fillWidth: true; Layout.leftMargin: 32
         spacing: 9
         RoundedImage { source: modelData.avatar||""; Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 9 }
         AppLabel { text: modelData.nickname||modelData.username||modelData.name||""; font.pixelSize: 13; color: app.ink; Layout.fillWidth: true; elide: Text.ElideRight }
         MD.Icon { name: "graphic_eq"; size: 18; color: app.accent }
        }
       }
      }
     }
     AppLabel { visible: !(page.kook.channels||[]).length; text: "暂无语音频道"; color: app.muted }
     ActionButton { text: "进入语音"; symbol: "headphones"; Layout.fillWidth: true; onClicked: Qt.openUrlExternally(page.kook.invite_url||page.kook.url||"https://www.kookapp.cn/app/") }
    }
   }
   MD.Card {
    Layout.fillWidth: true
    Layout.preferredHeight: 86
    type: MD.Enum.CardFilled; flat: true
    mdState.radius: 20; mdState.backgroundColor: app.colors.secondaryContainer
    horizontalPadding: 20
    onClicked: app.page=3
    contentItem: RowLayout {
     spacing: 12
     MD.Icon { name: "forum"; size: 24; color: app.colors.onSecondaryContainer }
     ColumnLayout { Layout.fillWidth: true; spacing: 5; AppLabel { text: "社区聊天"; color: app.colors.onSecondaryContainer; font.pixelSize: 14; font.weight: 600 } AppLabel { text: communityClient.chat.length?String(communityClient.chat[communityClient.chat.length-1].message||communityClient.chat[communityClient.chat.length-1].content||""):"查看聊天记录"; font.pixelSize: 13; color: app.colors.onSecondaryContainer; Layout.fillWidth: true; elide: Text.ElideRight } }
     MD.Icon { name: "arrow_forward"; size: 24; color: app.colors.onSecondaryContainer }
    }
   }
   MD.Pane {
    visible: !!app.activity.length
    Layout.fillWidth: true
    implicitHeight: activityContent.implicitHeight+40
    radius: 24; backgroundColor: app.panel
    ColumnLayout { id: activityContent; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 20; spacing: 16; AppLabel { text: "玩家动态"; font.weight: 600; color: app.ink } Repeater { model: app.activity.slice(0,5); AppLabel { required property var modelData; text: modelData.player+" 启动了 "+modelData.instance; color: app.muted; font.pixelSize: 13; wrapMode: Text.Wrap; Layout.fillWidth: true } } }
   }
  }
 }
 TextEdit {id:addressCopy;visible:false}
}
