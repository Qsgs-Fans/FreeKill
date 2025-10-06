// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects

import Fk

Item {
  property alias text: labelText.text
  property alias textColor: labelText.color
  property alias textFont: labelText.font
  property string iconSource
  property alias backgroundColor: rect.color
  property alias border: rect.border
  property bool autoHideText: true

  signal clicked

  id: button
  width: 124
  height: 124
  antialiasing: true

  RectangularGlow {
    anchors.fill: rect
    glowRadius: 1
    spread: 1.0
    visible: mouse.containsMouse || parent.focus
    antialiasing: true
  }

  Rectangle {
    id: rect
    anchors.fill: parent
    color: "#78D478"
    antialiasing: true
    border.width: 1
    border.color: "#8CDA8C"
  }

  transform: [
    Rotation {
      id: rotationTransform

      angle: 0

      axis.x: 0
      axis.y: 0
      axis.z: 0

      origin.x: button.width / 2.0
      origin.y: button.height / 2.0

      Behavior on angle {
        NumberAnimation { duration: 100 }
      }
    },

    Scale {
      id: scaleTransform

      xScale: 1
      yScale: 1

      origin.x: button.width / 2.0
      origin.y: button.height / 2.0

      Behavior on xScale {
        NumberAnimation { duration: 100 }
      }

      Behavior on yScale {
        NumberAnimation { duration: 100 }
      }
    }

  ]

  Image {
    id: icon
    anchors.centerIn: parent
    source: SkinBank.tileIconDir + iconSource
    scale: 0.8
  }

  Text {
    id: labelText

    anchors.bottom: parent.bottom
    anchors.bottomMargin: 3
    anchors.left: parent.left
    anchors.leftMargin: 3

    visible: !autoHideText || mouse.containsMouse

    color: "white"
    font.pixelSize: 16
    font.family: "WenQuanYi Micro Hei"

    text: "Button"
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true

    property bool down: false

    onPressed: {
      down = true;

      rotationTransform.axis.x = 0;
      rotationTransform.axis.y = 0;
      rotationTransform.origin.x = button.width / 2.0
      rotationTransform.origin.y = button.height / 2.0

      if (mouseX > parent.width - 30)
      {
        rotationTransform.origin.x = 0;
        rotationTransform.axis.y = 1;
        rotationTransform.angle = 15;
        return;
      }

      if (mouseX < 30) {
        rotationTransform.origin.x = button.width;
        rotationTransform.axis.y = 1;
        rotationTransform.angle = -15;
        return;
      }

      if (mouseY < 30) {
        rotationTransform.origin.y = button.height;
        rotationTransform.axis.x = 1;
        rotationTransform.angle = 15;
        return;
      }

      if (mouseY > parent.height - 30) {
        rotationTransform.origin.y = 0;
        rotationTransform.axis.x = 1;
        rotationTransform.angle = -15;
        return;
      }

      scaleTransform.xScale = 0.95;
      scaleTransform.yScale = 0.95;
    }

    onCanceled: {
      reset();
      down = false;
    }

    onReleased: {
      reset();
      if (down) {
        button.clicked();
      }
    }

    onExited: {
      reset();
      down = false;
    }

    function reset() {
      scaleTransform.xScale = 1;
      scaleTransform.yScale = 1;
      rotationTransform.angle = 0;
    }
  }

  Keys.onReturnPressed: {
    button.clicked();
  }
}
