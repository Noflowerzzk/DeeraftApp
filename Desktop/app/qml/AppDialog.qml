import QtQuick
import Qcm.Material as MD
MD.Dialog {
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: library.reducedMotion ? 0 : MD.Token.duration.short3; easing: MD.Token.easing.standard }
        NumberAnimation { property: "scale"; from: .96; to: 1; duration: library.reducedMotion ? 0 : MD.Token.duration.medium1; easing: MD.Token.easing.emphasized_decelerate }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: library.reducedMotion ? 0 : MD.Token.duration.short2; easing: MD.Token.easing.standard }
        NumberAnimation { property: "scale"; from: 1; to: .96; duration: library.reducedMotion ? 0 : MD.Token.duration.short2; easing: MD.Token.easing.emphasized_accelerate }
    }
    titleCapitalization: Font.MixedCase
}
