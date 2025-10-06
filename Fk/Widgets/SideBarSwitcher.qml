import QtQuick
import QtQuick.Controls

import Fk
import Fk.Widgets as W

ListView {
  id: root
  clip: true
  width: 130
  height: parent.height - 20
  y: 10
  ScrollBar.vertical: CommonScrollBar {}
  flickableDirection: Flickable.AutoFlickIfNeeded

  property alias background: bg
  Rectangle {
    id: bg
    z: -5
    anchors.fill: parent
    color: "#EBEBED"
  }

  highlight: Rectangle {
    color: "#D9D9DA"
    radius: 5
    scale: 0.9
  }
  highlightMoveDuration: 500

  delegate: Item {
    width: root.width
    height: 40

    Text {
      text: Lua.tr(name)
      anchors.centerIn: parent
    }

    W.TapHandler {
      onTapped: {
        root.currentIndex = index;
      }
    }
  }
}
