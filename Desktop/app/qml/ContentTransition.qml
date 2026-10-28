import QtQuick
import Qcm.Material as MD

// Top-level fade-through or shared-axis replacement; retarget without restarting velocity.
QtObject {
    id: motion
    required property Item target
    property bool reducedMotion: library.reducedMotion
    property bool horizontal: true
    property bool translateContent: true
    property int direction: 1
    property int phase: 0
    readonly property bool running: phase !== 0
    property var pendingUpdate: null
    property Translate offset: Translate { x:motion.horizontal?motion.spatial.value:0;y:motion.horizontal?0:motion.spatial.value }
    property Binding opacityBinding: Binding {target:motion.target;property:"opacity";value:Math.max(0,Math.min(1,motion.fade.value))}
    property MD.SpringMotion fade: MD.SpringMotion {
        targetValue:motion.phase===1?0:1
        spec:MD.Token.motion.spring.expressive.fastEffects
        enabled:!motion.reducedMotion
        visibilityThreshold:.005
        onFinished:motion.settled()
    }
    property MD.SpringMotion spatial: MD.SpringMotion {
        targetValue:motion.translateContent&&motion.phase===1?-motion.direction*16:0
        spec:MD.Token.motion.spring.expressive.fastSpatial
        enabled:!motion.reducedMotion
        onFinished:motion.settled()
    }
    Component.onCompleted:if(target)target.transform=[offset]
    function applyPending(){var update=pendingUpdate;pendingUpdate=null;if(update)update()}
    function finishImmediately(){phase=0;applyPending();fade.complete();spatial.complete()}
    function settled(){
        if(phase===1&&!fade.running){
            applyPending();
            if(translateContent)spatial.snapTo(direction*(horizontal?28:20));
            phase=2;
        }else if(phase===2&&!fade.running&&!spatial.running)phase=0;
    }
    function run(update){
        pendingUpdate=update;
        if(!target||!target.visible||reducedMotion){finishImmediately();return}
        phase=1;
        if(!fade.running)settled();
    }
    onReducedMotionChanged:if(reducedMotion&&fade&&spatial)finishImmediately()
}
