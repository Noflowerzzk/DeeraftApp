import QtQuick
import Qcm.Material as MD
MD.Menu {
    id: control
    implicitWidth: 260
    function showAt(item) { anchorItem = item; open() }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: library.reducedMotion ? 0 : 150; easing: MD.Token.easing.emphasized_decelerate } NumberAnimation { property: "scale"; from: .96; to: 1; duration: library.reducedMotion ? 0 : 200; easing: MD.Token.easing.emphasized_decelerate } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: library.reducedMotion ? 0 : 100; easing: MD.Token.easing.emphasized_accelerate } NumberAnimation { property: "scale"; from: 1; to: .96; duration: library.reducedMotion ? 0 : 100; easing: MD.Token.easing.emphasized_accelerate } }
    background: MD.ElevationRectangle { radius: 20; color: control.MD.MProp.color.surface_container_high; elevation: 2 }
}
