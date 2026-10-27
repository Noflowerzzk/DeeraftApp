import QtQuick
import Qcm.Material as MD
Text {
 property string name: ""
 text: name
 font.family: "Material Symbols Rounded"
 font.pixelSize: 24
 font.features: ({ "liga": 1 })
 horizontalAlignment: Text.AlignHCenter
 verticalAlignment: Text.AlignVCenter
 renderType: Text.NativeRendering
}
