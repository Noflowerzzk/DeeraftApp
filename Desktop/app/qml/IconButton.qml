import QtQuick
import Qcm.Material as MD
MD.IconButton {
    id: control
    property string symbol: ""
    property string hint: ""
    property color ink: MD.MProp.color.on_surface_variant
    icon.name: symbol
    icon.color: ink
    mdState.type: MD.Enum.IBtStandard
    MD.ToolTip.text: hint
    MD.ToolTip.visible: control.mdState.interactions.hovered && hint.length > 0
    animationsEnabled: !library.reducedMotion
    implicitWidth: 40
    implicitHeight: 40
}
