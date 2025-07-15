import QtQuick
import QtQuick.Controls

ScrollBar {
  id: root
  width: active ? 10 : 6
  anchors.right: parent.right
  hoverEnabled: true
  active: hovered || pressed
  orientation: Qt.Vertical
  policy: ScrollBar.AsNeeded
  Behavior on width {
    NumberAnimation { duration: 200 }
  }

  property color scrollBarColor: "#808080"

  contentItem: Rectangle {
    implicitWidth: 6
    implicitHeight: 100
    radius: width / 2
    color: root.pressed ? Qt.darker(root.scrollBarColor, 1.2)
    : root.hovered ? Qt.darker(root.scrollBarColor, 1.1)
    : root.scrollBarColor
    opacity: root.active ? 0.8 : 0.0

    Behavior on opacity {
      OpacityAnimator { duration: 200 }
    }
  }

  background: Rectangle {
    implicitWidth: 8
    color: "#E6E6E6"
    opacity: root.active ? 0.8 : 0.0
    Behavior on opacity {
      OpacityAnimator { duration: 200 }
    }
  }
}
