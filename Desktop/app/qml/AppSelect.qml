import QtQuick
import Qcm.Material as MD
MD.ComboBox {
    id: control
    property alias caption: control.label
    signal activated(int index)
    onSelectionChangeRequested: function(index,value) { control.activated(index); if(control.currentIndex!==index)control.currentIndex=index }
    type: MD.Enum.TextFieldFilled
    implicitHeight: 60
    font.pixelSize: 14
    popupMaximumWidth: 320
    popupMaximumHeight: 320
    // Unified Expressive menu motion: gentle scale and coordinated opacity.
    Binding { target: control; property: "__labelAnimationsEnabled"; value: false }
    popup.enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: library.reducedMotion ? 0 : 150; easing: MD.Token.easing.emphasized_decelerate } NumberAnimation { property: "scale"; from: .96; to: 1; duration: library.reducedMotion ? 0 : 200; easing: MD.Token.easing.emphasized_decelerate } }
    popup.exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: library.reducedMotion ? 0 : 100; easing: MD.Token.easing.emphasized_accelerate } NumberAnimation { property: "scale"; from: 1; to: .96; duration: library.reducedMotion ? 0 : 100; easing: MD.Token.easing.emphasized_accelerate } }
    popup.background: MD.ElevationRectangle {
        implicitWidth: 200
        implicitHeight: 48
        radius: 20
        color: control.MD.MProp.color.surface_container_high
        elevation: 2
    }
}
