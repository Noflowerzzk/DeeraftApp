pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Qcm.Material as MD

MD.SideSheetBase {
    id: control
    objectName:"materialSideSheet"
    property bool animationsEnabled: true
    property color color: MD.Token.color.surface
    property int elevation: MD.Token.elevation.level0
    property int radius: detached ? MD.Token.shape.corner.large : 0
    property int __revision: 0

    sheetItem.contentItem.clip: true
    sheetItem.background: MD.ElevationRectangle {
        color: control.color
        elevation: control.elevation
        corners: control.detached ? MD.Util.corners(control.radius) : control.effectiveEdge === Qt.LeftEdge ? MD.Util.corners(0, control.radius, 0, control.radius) : MD.Util.corners(control.radius, 0, control.radius, 0)
    }

    onTransitionRequested: (revision, target, animate) => {
        __revision = revision;
        if (!animate || !animationsEnabled) {
            sheetMotion.snapTo(target);
            position = target;
            completeTransition(revision);
        } else {
            if (!sheetMotion.running) sheetMotion.snapTo(position);
            sheetMotion.targetValue = target;
            if (!sheetMotion.running) completeTransition(revision);
        }
    }
    onStateChanged: if (dragging) sheetMotion.stop()
    onAnimationsEnabledChanged: if (!animationsEnabled && sheetMotion.running) {
        sheetMotion.complete();
        completeTransition(__revision);
    }
    MD.SpringMotion {
        id: sheetMotion
        objectName:"sideSheetMotion"
        spec: MD.Token.motion.spring.expressive.defaultSpatial
        visibilityThreshold: .0005
        onValueChanged: if (!control.dragging) control.position = Math.max(0, Math.min(1, value))
        onFinished: control.completeTransition(control.__revision)
    }
}
