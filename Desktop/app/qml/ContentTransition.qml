import QtQuick
import Qcm.Material as MD

// Coordinate replacement without animating layout-owned positions.
QtObject {
    id: motion
    required property Item target
    property bool reducedMotion: library.reducedMotion
    readonly property bool running: (exitAnimation && exitAnimation.running) || (enterAnimation && enterAnimation.running)
    property var pendingUpdate: null

    function applyPending() {
        var update = pendingUpdate;
        pendingUpdate = null;
        if (update) update();
    }
    function finishImmediately() {
        exitAnimation.stop();
        enterAnimation.stop();
        applyPending();
        if (target) { target.opacity = 1; target.scale = 1; }
    }
    function run(update) {
        pendingUpdate = update;
        if (!target || !target.visible || reducedMotion) { finishImmediately(); return; }
        enterAnimation.stop();
        // A second request updates the destination without restarting the exit.
        if (!exitAnimation.running) exitAnimation.start();
    }
    onReducedMotionChanged: if (reducedMotion && exitAnimation && enterAnimation) finishImmediately()

    property NumberAnimation exitAnimation: NumberAnimation {
        target: motion.target
        property: "opacity"
        to: 0
        duration: MD.Token.duration.short2
        easing: MD.Token.easing.emphasized_accelerate
        onFinished: {
            motion.applyPending();
            motion.target.scale = .985;
            motion.enterAnimation.start();
        }
    }
    property ParallelAnimation enterAnimation: ParallelAnimation {
        NumberAnimation {
            target: motion.target; property: "opacity"; to: 1
            duration: MD.Token.duration.short4; easing: MD.Token.easing.emphasized_decelerate
        }
        NumberAnimation {
            target: motion.target; property: "scale"; to: 1
            duration: MD.Token.duration.medium2; easing: MD.Token.easing.emphasized_decelerate
        }
    }
}
