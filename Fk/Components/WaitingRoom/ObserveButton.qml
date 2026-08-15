import QtQuick

import Fk
import Fk.Components.GameCommon

BasicItem {
  id: root
  width: 80
  height: 80

  property bool hovered: false

  property alias bg: bg

  scale: pressed ? 0.95 : 1

  Rectangle {
    id: bg
    anchors.fill: parent
    color: 'transparent'
    radius: Math.round(root.height / 5)
    border.color: root.hovered ? '#c2ddda' : '#9fbebb'
    border.width: 4
  }

  Text {
    text: Lua.tr("Spectate")
    font.bold: true
    font.pixelSize: 23
    font.letterSpacing: 2
    color: root.hovered ? '#c2ddda' : '#9fbebb'
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    anchors.fill: parent
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

  Behavior on y {
    NumberAnimation{ easing.type: Easing.OutCubic; duration: 100 }
  }
}