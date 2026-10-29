import QtQuick
import Qcm.Material as MD
MD.Label {
    color: MD.MProp.color.on_surface
    useTypescale: false
    lineHeightMode: Text.FixedHeight
    lineHeight: Math.round(font.pixelSize*1.5)
    wrapMode: Text.NoWrap
    font.pixelSize: 14
    textFormat: Text.PlainText
}
