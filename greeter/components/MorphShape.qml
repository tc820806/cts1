import QtQuick
import QtQuick.Shapes
import qs

// One baked Shapes pair at `progress` (0 = A, 1 = B), `size` px square. Size set here: a Shape sizes itself from its
// path, so path <-> size would be a binding loop.
Shape {
    id: root

    property var pair
    property real progress: 0
    property color color: "white"
    property real size

    width: size
    height: size

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        strokeWidth: 0

        PathSvg {
            path: Shapes.path(root.pair, root.progress, root.size)
        }
    }
}
