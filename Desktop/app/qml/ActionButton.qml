import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
Button {
 id: control
 property string symbol: ""
 property bool splitLeft:false
 property bool splitRight:false
 topInset: 0; bottomInset: 0
 implicitHeight: 44
 leftPadding: 20; rightPadding: 20
 Material.elevation: 0
 contentItem: RowLayout {
   spacing: 8
   AppIcon { visible: control.symbol.length>0; name: control.symbol; font.pixelSize: 20; color: label.color }
   Label { textFormat: Text.PlainText; id: label; text: control.text; font: control.font; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true
     color: !control.enabled ? (desktop.dark?"#75827c":"#7d8983") : control.highlighted && !control.flat ? (desktop.dark?"#00382d":"#ffffff") : (desktop.dark?"#cde8e0":"#005144") }
 }
 background: Rectangle { radius: control.down ? 12 : height/2; topLeftRadius: control.splitRight?4:radius; bottomLeftRadius: control.splitRight?4:radius; topRightRadius: control.splitLeft?4:radius; bottomRightRadius: control.splitLeft?4:radius; color: control.flat ? (control.hovered ? (desktop.dark?"#233c34":"#e3eae6") : "transparent") : control.highlighted ? (desktop.dark?"#84d6c3":"#056b5b") : (desktop.dark?"#334b45":"#cde8e0"); opacity: control.enabled?1:.55
   Behavior on radius { enabled: !library.reducedMotion; NumberAnimation { duration: 140 } }
 }
 scale: down ? .98 : 1
 Behavior on scale { enabled: !library.reducedMotion; SpringAnimation { spring: 5; damping: .8; mass: 1 } }
}
