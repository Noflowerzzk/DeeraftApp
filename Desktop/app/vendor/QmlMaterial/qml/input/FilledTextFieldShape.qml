import QtQuick
import QtQuick.Shapes
import Qcm.Material as MD

MD.Shape {
    id: root
    // CurveRenderer can retain a blank node after hidden-page transitions in embedded Qt 6.12 views.
    preferredRendererType: Shape.GeometryRenderer
    property real radius: 0
    property color color: "black"
    property alias bottomLineColor: m_line.strokeColor
    property alias bottomLineWidth: m_line.strokeWidth

    MD.RoundPath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: root.color
        width: root.width
        height: root.height
        corners: MD.Util.corners(root.radius, 0)
    }

    ShapePath {
        id: m_line
        strokeWidth: 1
        strokeColor: "transparent"
        fillColor: "transparent"
        startX: strokeWidth / 2
        startY: root.height
        PathLine {
            x: root.width - m_line.strokeWidth / 2
            y: root.height
        }
    }
}
