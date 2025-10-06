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

  Repeater {
    id: eggs
    model: 7

    Item {
      property real xOffset
      property real yOffset

      Image {
        id: egg
        source: SkinBank.pixAnimDir + "/wine/egg"
        x: start.x - width / 2 + xOffset
        y: start.y - height / 2 + yOffset
        scale: 0.7
        opacity: 0
        rotation: (Math.atan(Math.abs(end.y - start.y)
          / Math.abs(end.x - start.x))
          / Math.PI * 180 - 90) * (end.x > start.x ? -1 : 1)
      }

      Image {
        id: whip
        x: end.x - width / 2 + xOffset
        y: end.y - height / 2 + yOffset
        property int idx: 0
        opacity: 0
        scale: 1.7
        source: SkinBank.pixAnimDir + "/wine/egg" + idx
      }

      SequentialAnimation {
        id: flyAnim
        ScriptAction {
          script: {
            egg.opacity = 1;
          }
        }
        ParallelAnimation {
          PropertyAnimation {
            target: egg
            property: "x"
            to: end.x - egg.width / 2 + xOffset
            duration: 250
          }
          PropertyAnimation {
            target: egg
            property: "y"
            to: end.y - egg.height / 2 + yOffset
            duration: 250
          }
        }
        ScriptAction {
          script: {
            egg.opacity = 0;
            whip.opacity = 1;
          }
        }
        PropertyAnimation {
          target: whip
          property: "idx"
          to: 18
          duration: 370
        }
        ScriptAction {
          script: {
            whip.opacity = 0;
          }
        }
      }

      function startAnim() { flyAnim.start(); }

      Component.onCompleted: {
        xOffset = Math.random() * 70 - 35;
        yOffset = Math.random() * 70 - 30;
      }
    }
  }

  Image {
    id: shoeS
    source: SkinBank.pixAnimDir + "/wine/shoe_s"
    x: start.x - width / 2
    y: start.y - height / 2
    scale: 0
  }

  Image {
    id: shoe
    source: SkinBank.pixAnimDir + "/wine/shoe"
    x: start.x - width / 2
    y: start.y - height / 2
    scale: 0
  }

  Image {
    id: hit
    x: end.x - width / 2
    y: end.y - height / 2
    property int idx: 1
    opacity: 0
    scale: 1.2
    source: SkinBank.pixAnimDir + "/shoe/hit" + idx
  }

  property int seqIdx: 0

  SequentialAnimation {
    id: pointToAnimation
    running: false

    ScriptAction {
      script: Backend.playSound("./audio/system/wine1");
    }

    SequentialAnimation {
      loops: 7
      ScriptAction {
        script: {
          const e = eggs.itemAt(seqIdx);
          e.startAnim();
          seqIdx++;
        }
      }
      PauseAnimation { duration: 320 }
    }

    PauseAnimation { duration: 200 }

    ScriptAction {
      script: Backend.playSound("./audio/system/wine2");
    }

    ParallelAnimation {
      PropertyAnimation {
        target: shoe
        property: "scale"
        to: 1
        duration: 660
      }

      PropertyAnimation {
        target: shoe
        property: "x"
        to: end.x - shoe.width / 2
        duration: 660
      }

      PropertyAnimation {
        target: shoe
        property: "y"
        to: end.y - shoe.height / 2
        duration: 660
      }

      PropertyAnimation {
        target: shoe
        property: "rotation"
        to: 360
        duration: 330
        loops: 2
      }

      SequentialAnimation {
        PauseAnimation { duration: 80 }
        ParallelAnimation {
          PropertyAnimation {
            target: shoeS
            property: "scale"
            to: 1
            duration: 660
          }

          PropertyAnimation {
            target: shoeS
            property: "x"
            to: end.x - shoeS.width / 2
            duration: 660
          }

          PropertyAnimation {
            target: shoeS
            property: "y"
            to: end.y - shoeS.height / 2
            duration: 660
          }

          PropertyAnimation {
            target: shoeS
            property: "rotation"
            to: 360
            duration: 330
            loops: 2
          }
        }
      }

      SequentialAnimation {
        PauseAnimation { duration: 660 }
        ScriptAction {
          script: {
            hit.opacity = 1;
          }
        }
        PropertyAnimation {
          target: hit
          property: "idx"
          to: 10
          duration: 300
        }
      }
    }

    ParallelAnimation {
      PropertyAnimation {
        target: shoe
        property: "opacity"
        to: 0
        duration: 100
      }
      PropertyAnimation {
        target: shoe
        property: "y"
        to: end.y - shoe.height / 2 + 20
        duration: 100
      }
      PropertyAnimation {
        target: shoeS
        property: "opacity"
        to: 0
        duration: 100
      }
    }

    onStopped: {
      root.visible = false;
      root.finished();
    }
  }
}
