// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk.Widgets as W

Item {
  property bool enabled: true
  property alias text: title.text
  property alias textColor: title.color
  property alias textFont: title.font
  property alias backgroundColor: bg.color
  property alias border: bg.border
  property alias iconSource: icon.source
  property int padding: 5
  property bool hovered: false

  signal clicked
  signal rightClicked

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
      name: "hovered"; when: hover.hovered
      PropertyChanges { target: bg; color: "white" }
      PropertyChanges { target: title; color: "black" }
    },
    State {
      name: "disabled"; when: !enabled
      PropertyChanges { target: button; opacity: 0.2 }
    }
  ]

  W.TapHandler {
    id: mouse
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.NoButton
    gesturePolicy: TapHandler.WithinBounds

    onTapped: (p, btn) => {
      if (parent.enabled) {
        if (btn === Qt.LeftButton || btn === Qt.NoButton) {
          parent.clicked();
        } else if (btn === Qt.RightButton) {
          parent.rightClicked();
        }
      }
    }

    onLongPressed: {
      parent.rightClicked();
    }
  }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
    onHoveredChanged: {
      if (hovered) {
        button.hovered = true;
      } else {
        button.hovered = false;
      }
    }
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
