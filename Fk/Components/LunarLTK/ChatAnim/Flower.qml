// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk

Item {
  id: root
  anchors.fill: parent
  property point start: Qt.point(0, 0)
  property point end: Qt.point(0, 0)
  property alias running: pointToAnimation.running

  signal finished()

  Image {
    id: egg
    source: SkinBank.pixAnimDir + "/flower/egg"
    x: start.x - width / 2
    y: start.y - height / 2
    scale: 0.7
    rotation: Math.atan(Math.abs(end.y - start.y) / Math.abs(end.x - start.x))
      / Math.PI * 180 + 90 * (end.x > start.x ? 1 : -1)
  }

  Image {
    id: whip
    x: end.x - width / 2
    y: end.y - height / 2
    property int idx: 1
    opacity: 0
    scale: 0.7
    source: SkinBank.pixAnimDir + "/flower/egg" + idx
  }

  Image {
    id: star
    opacity: 0
    source: SkinBank.pixAnimDir + "/flower/star"
    scale: 0.7
  }

  SequentialAnimation {
    id: pointToAnimation
    running: false
    ScriptAction {
      script: Backend.playSound("./audio/system/fly" +
                                (Math.floor(Math.random() * 2) + 1));
    }

    ParallelAnimation {
      PropertyAnimation {
        target: egg
        property: "scale"
        to: 0.5
        duration: 360
      }

      PropertyAnimation {
        target: egg
        property: "x"
        to: end.x - egg.width / 2
        duration: 360
      }

      PropertyAnimation {
        target: egg
        property: "y"
        to: end.y - egg.height / 2
        duration: 360
      }

      SequentialAnimation {
        PauseAnimation { duration: 300 }
        PropertyAnimation {
          target: egg
          property: "opacity"
          to: 0
          duration: 60
        }
      }
    }

    ScriptAction {
      script: Backend.playSound("./audio/system/flower" +
                                (Math.floor(Math.random() * 2) + 1));
    }

    ParallelAnimation {
      SequentialAnimation {
        SequentialAnimation {
          PauseAnimation { duration: 180 }
          ScriptAction { script: whip.idx++; }
          loops: 2
        }

        ScriptAction {
          script: {
            star.x = end.x - 25;
            star.y = end.y - 35;
          }
        }

        SequentialAnimation {
          PropertyAnimation {
            target: star
            property: "opacity"
            to: 1
            duration: 100
          }

          PauseAnimation { duration: 100 }

          PropertyAnimation {
            target: star
            property: "opacity"
            to: 0
            duration: 100
          }

          ScriptAction {
            script: {
              star.x = end.x - 10;
              star.y = end.y - 20;
            }
          }
        }

        SequentialAnimation {
          PropertyAnimation {
            target: star
            property: "opacity"
            to: 1
            duration: 100
          }

          PauseAnimation { duration: 100 }

          PropertyAnimation {
            target: star
            property: "opacity"
            to: 0
            duration: 100
          }
        }
      }

      SequentialAnimation {
        PropertyAnimation {
          target: whip
          property: "opacity"
          to: 1
          duration: 100
        }

        PauseAnimation { duration: 1100 }

        PropertyAnimation {
          target: whip
          property: "opacity"
          to: 0
          duration: 100
        }
      }
    }

    onStopped: {
      root.visible = false;
      root.finished();
    }
  }
}
