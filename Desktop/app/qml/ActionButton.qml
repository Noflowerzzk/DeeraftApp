import QtQuick
import Qcm.Material as MD
MD.Button {
    id: control
    property string symbol: ""
    property bool highlighted: false
    property bool splitLeft: false
    property bool splitRight: false
    flat: false
    icon.name: symbol
    mdState.type: flat ? MD.Enum.BtText : highlighted ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal
    mdState.size: MD.Enum.S
    shapeSpringSpec: MD.Token.motion.spring.expressive.fastSpatial
    font.pixelSize: 14
    font.weight: Font.Medium
    animationsEnabled: !library.reducedMotion
    MD.SpringMotion { id: pressFeedback; targetValue: control.mdState.interactions.pressed?.98:1; enabled: !library.reducedMotion; spec: MD.Token.motion.spring.expressive.fastSpatial }
    scale: pressFeedback.value
}
