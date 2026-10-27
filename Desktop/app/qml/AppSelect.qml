import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ComboBox {
 id: control
 implicitHeight: 54
 property string caption: ""
 property color ink: desktop.dark?"#dce5df":"#171d1b"
 contentItem: Column {
   leftPadding: 12; rightPadding: 32
   Text { visible: control.caption.length>0; text: control.caption; font.pixelSize: 11; color: desktop.dark?"#bec9c5":"#3f4946" }
   Text { width: parent.width-44; text: control.displayText; font.pixelSize: 13; color: control.ink; elide: Text.ElideRight }
 }
 indicator: AppIcon { name: "arrow_drop_down"; color: control.ink; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 20 }
 background: Rectangle { color: desktop.dark?"#303b36":"#dee4e0"; radius: 4; Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: control.activeFocus? (desktop.dark?"#84d6c3":"#056b5b") : (desktop.dark?"#89938d":"#6f7976") } }
 popup: Popup {
   y: control.height+4; width: Math.max(control.width,240); padding: 8
   implicitHeight: Math.min(menuList.contentHeight+16,320)
   enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: library.reducedMotion?0:150 } }
   exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: library.reducedMotion?0:75 } }
   background: Rectangle { radius: 20; color: desktop.dark?"#28312d":"#e3eae6"; border.width: 0 }
   contentItem: ListView { id: menuList; clip: true; model: control.delegateModel; currentIndex: control.highlightedIndex; ScrollIndicator.vertical: ScrollIndicator {} }
 }
 delegate: ItemDelegate {
   required property int index
   width: control.popup.width-16; height: 44
   text: control.textAt(index)
   contentItem: RowLayout {
     Label { textFormat: Text.PlainText; text: control.textAt(index); color: control.ink; elide: Text.ElideRight; Layout.fillWidth: true; font.pixelSize: 13 }
     AppIcon { name: "check"; visible: index===control.currentIndex; color: control.ink; font.pixelSize: 18 }
   }
   background: Rectangle { radius: 12; color: index===control.currentIndex? (desktop.dark?"#334b45":"#cde8e0") : parent.hovered? (desktop.dark?"#38433d":"#d3ddd7") : "transparent" }
   onClicked: { control.currentIndex=index; control.activated(index); control.popup.close() }
 }
}
