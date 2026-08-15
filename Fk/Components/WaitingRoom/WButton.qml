import QtQuick

import Fk.Components.GameCommon

BasicItem {
  id: root
  width: 50
  height: 30

  property bool hovered: false

  property alias bg: bg
  property alias border: bg.border
  property alias title: title
  property alias text: title.text
  property alias textFont: title.font

  scale: (enabled && pressed) ? 0.95 : 1
  opacity: enabled ? 1 : 0.5

  Rectangle {
    id: bg
    anchors.fill: parent
    color: '#bcd1ca'
    radius: 4
    border.color: '#749491'
    border.width: (root.enabled && root.pressed) ? 2 : 1
    clip: true

    Rectangle {
      width: root.width
      height: root.height
      radius: bg.radius
      y: root.hovered ? 0 : width
      opacity: 0.2
      color: "snow"

      Behavior on y {
        NumberAnimation{ easing.type: Easing.OutCubic; duration: 100 }
      }
    }
  }

  Text {
    id: title
    anchors.fill: parent
    text: ""
    color: '#709ea3'
    font.bold: true
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  HoverHandler {
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onHoveredChanged: {
      if (hovered && parent.enabled && parent.selectable) {
        parent.hovered = true;
      } else {
        parent.hovered = false;
      }
    }
  }
}
