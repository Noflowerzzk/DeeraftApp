import QtQuick
import QtQuick.Controls
AbstractButton {
 id: control
 property string symbol: "more_vert"
 property string hint: ""
 property color ink: desktop.dark ? "#c0c9c4" : "#3f4946"
 implicitWidth: 40; implicitHeight: 40
 contentItem: AppIcon { name: control.symbol; color: control.ink }
 background: Rectangle { radius: 20; color: control.down ? (desktop.dark?"#38534b":"#d7e4de") : control.hovered ? (desktop.dark?"#293b34":"#e3eae6") : "transparent" }
 ToolTip.visible: hovered && hint.length>0
 ToolTip.text: hint
 Accessible.name: hint
}
