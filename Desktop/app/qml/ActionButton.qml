import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

Button {
    id: control
    Material.elevation: 0
    contentItem: Label {
        text: control.text
        font: control.font
        color: !control.enabled ? control.Material.hintTextColor
            : control.highlighted && !control.flat ? (desktop.dark ? "#07391c" : "#ffffff")
            : control.Material.foreground
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    scale: down ? 0.98 : 1
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
}
