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
    source: SkinBank.PIXANIM_DIR + "/egg/egg"
    x: start.x - width / 2
    y: start.y - height / 2
    scale: 0.7
    opacity: 0
  }

  Image {
    id: whip
    x: end.x - width / 2
    y: end.y - height / 2
    property int idx: 1
    opacity: 0
    scale: 0.7
    source: SkinBank.PIXANIM_DIR + "/egg/egg" + idx
  }

  SequentialAnimation {
    id: pointToAnimation
    running: false
    PropertyAnimation {
      target: egg
      property: "opacity"
      to: 1
      duration: 400
    }

    PauseAnimation {
      duration: 350
    }

    ScriptAction {
      script: Backend.playSound("./audio/system/fly" +
                                (Math.floor(Math.random() * 2) + 1));
    }

    ParallelAnimation {
      PropertyAnimation {
        target: egg
        property: "scale"
        to: 0.4
        duration: 500
      }

      PropertyAnimation {
        target: egg
        property: "x"
        to: end.x - egg.width / 2
        duration: 500
      }

      PropertyAnimation {
        target: egg
        property: "y"
        to: end.y - egg.height / 2
        duration: 500
      }

      PropertyAnimation {
        target: egg
        property: "rotation"
        to: 360
        duration: 250
        loops: 2
      }

      SequentialAnimation {
        PauseAnimation { duration: 400 }
        PropertyAnimation {
          target: egg
          property: "opacity"
          to: 0
          duration: 100
        }
      }
    }

    ScriptAction {
      script: Backend.playSound("./audio/system/egg" +
                                (Math.floor(Math.random() * 2) + 1));
    }

    ParallelAnimation {
      SequentialAnimation {
        SequentialAnimation {
          PauseAnimation { duration: 160 }
          ScriptAction { script: whip.idx++; }
          loops: 2
        }

        PauseAnimation { duration: 160 }
      }

      SequentialAnimation {
        PropertyAnimation {
          target: whip
          property: "opacity"
          to: 1
          duration: 100
        }

        PauseAnimation { duration: 300 }

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
