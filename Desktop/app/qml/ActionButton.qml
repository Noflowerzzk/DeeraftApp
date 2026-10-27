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
    font.pixelSize: 14
    font.weight: Font.Medium
    animationsEnabled: !library.reducedMotion
}
