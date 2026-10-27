import QtQuick
import QtQuick.Effects
Item {
 id:root
 property alias source:image.source
 property real radius:24
 Image {id:image;anchors.fill:parent;fillMode:Image.PreserveAspectCrop;asynchronous:true;visible:false}
 Rectangle {id:mask;anchors.fill:parent;radius:root.radius;color:"white";layer.enabled:true;visible:false}
 MultiEffect {anchors.fill:parent;source:image;maskEnabled:true;maskSource:mask;autoPaddingEnabled:false}
}
