import QtQuick

// One PopupHost popup: a `name` and one content child, whose implicit size sizes the box.
Item {
    property string name: ""
    // For content that can't report its own width.
    property real preferredWidth: 0
    readonly property Item content: children.length > 0 ? children[0] : null

    implicitWidth: preferredWidth > 0 ? preferredWidth : (content ? content.implicitWidth : 0)
    implicitHeight: content ? content.implicitHeight : 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    visible: false      // PopupHost shows the current one
}
