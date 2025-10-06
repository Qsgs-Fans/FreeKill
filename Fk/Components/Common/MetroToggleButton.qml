// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk.Widgets as W

Item {
  property bool enabled: true
  property bool triggered: false
  property alias text: title.text
  property alias textColor: title.color
  property alias textFont: title.font
  property alias backgroundColor: bg.color
  property alias border: bg.border
  property alias iconSource: icon.source
  property int padding: 5

  signal clicked

  id: button
  width: icon.width + title.implicitWidth + padding * 2
  height: Math.max(icon.height, title.implicitHeight) + padding * 2

  Rectangle {
    id: bg
    anchors.fill: parent
    color: "black"
    border.width: 2
    border.color: "white"
    opacity: 0.8
  }

  states: [
    State {
      name: "hovered_checked"; when: hover.hovered && triggered
      PropertyChanges { target: bg; color: "gold" }
      PropertyChanges { target: title; color: "black" }
    },
    State {
      name: "hovered"; when: hover.hovered
      PropertyChanges { target: bg; color: "white" }
      PropertyChanges { target: title; color: "black" }
    },
    State {
      name: "checked"; when: triggered
      PropertyChanges { target: border; color: "gold" }
      PropertyChanges { target: title; color: "gold" }
    },
    State {
      name: "disabled"; when: !enabled
      PropertyChanges { target: button; opacity: 0.2 }
    }
  ]

  W.TapHandler {
    id: mouse
    onTapped: if (parent.enabled) {
      triggered = !triggered;
      parent.clicked();
    }
  }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
  }

  Row {
    x: padding
    y: padding
    anchors.centerIn: parent
    spacing: 5

    Image {
      id: icon
      anchors.verticalCenter: parent.verticalCenter
      fillMode: Image.PreserveAspectFit
    }

    Text {
      id: title
      font.pixelSize: 18
      // font.family: "WenQuanYi Micro Hei"
      anchors.verticalCenter: parent.verticalCenter
      text: ""
      color: "white"
    }
  }
}
