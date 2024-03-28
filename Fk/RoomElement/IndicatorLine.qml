// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

Item {
  property point start: Qt.point(0, 0)
  property var end: []
  property alias running: pointToAnimation.running
  property color color: "#96943D"
  property real ratio: 0
  property int lineWidth: 6

  signal finished()

  id: root
  anchors.fill: parent

  Repeater {
    model: end

    Rectangle {
      width: 6
      height: Math.sqrt(Math.pow(modelData.x - start.x, 2) +
                        Math.pow(modelData.y - start.y, 2)) * ratio
      x: start.x
      y: start.y
      antialiasing: true

      gradient: Gradient {
        GradientStop {
          position: 0
          color: Qt.rgba(255, 255, 255, 0)
        }
        GradientStop {
          position: 1
          color: Qt.rgba(200, 200, 200, 0.12)
        }
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 3
        height: parent.height
        antialiasing: true

        gradient: Gradient {
          GradientStop {
            position: 0
            color: Qt.rgba(255, 255, 255, 0)
          }
          GradientStop {
            position: 1
            color: Qt.lighter(root.color)
          }
        }
      }

      transform: Rotation {
        angle: 0

        Component.onCompleted: {
          var dx = modelData.x - start.x;
          var dy = modelData.y - start.y;
          if (dx > 0) {
            angle = Math.atan2(dy, dx) / Math.PI * 180 - 90;
          } else if (dx < 0) {
            angle = Math.atan2(dy, dx) / Math.PI * 180 + 270;
          } else if (dy < 0) {
            angle = 180;
          }
        }
      }
    }
  }

  SequentialAnimation {
    id: pointToAnimation

    PropertyAnimation {
      target: root
      property: "ratio"
      to: 1
      easing.type: Easing.OutCubic
      duration: 200
    }

    PauseAnimation {
      duration: 200
    }

    PropertyAnimation {
      target: root
      property: "opacity"
      to: 0
      easing.type: Easing.InQuart
      duration: 300
    }

    onStopped: {
      root.visible = false;
      root.finished();
    }
  }
}
