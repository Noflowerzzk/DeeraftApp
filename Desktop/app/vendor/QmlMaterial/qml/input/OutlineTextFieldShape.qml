import QtQuick
import QtQuick.Shapes
import Qcm.Material as MD

MD.Shape {
    id: root
    preferredRendererType: Shape.GeometryRenderer
    property bool animationsEnabled: true
    property bool __completed: false
    Component.onCompleted: __completed = true
    property real radius: 0
    property alias borderWidth: m_p.strokeWidth
    property alias borderColor: m_p.strokeColor
    property real floatX: 0
    property real floatWidth: 0

    property real openX: floatX + floatWidth / 2
    property real openWidth: 0
    property bool open: false

    state: open ? 'open' : 'close'
    states: [
        State {
            name: 'open'
            PropertyChanges {
                root.openX: root.floatX
                root.openWidth: root.floatWidth
            }
        }
    ]
    transitions: [
        Transition {
            enabled: root.__completed && root.animationsEnabled
            NumberAnimation {
                properties: "openX,openWidth"
                duration: MD.Token.duration.medium4
                easing: MD.Token.easing.emphasized
            }
        }
    ]

    MD.Shape {
      x:m_p.strokeWidth/2; y:m_p.strokeWidth/2
      width:root.width-m_p.strokeWidth; height:root.height-m_p.strokeWidth
      preferredRendererType: Shape.GeometryRenderer
    MD.RoundPath {
        id: m_p
        strokeWidth: 1
        strokeColor: "black"
        fillColor: "transparent"
        width: Math.max(0, root.width - strokeWidth)
        height: Math.max(0, root.height - strokeWidth)
        corners: MD.Util.corners(root.radius)
        startX: Math.max(m_p.corners.topLeft, root.openX) + root.openWidth

        // last is top left
        PathLine {
            x: Math.max(m_p.corners.topLeft, root.openX)
            y: 0
        }
    }
    }
}
