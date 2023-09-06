// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk

Image {
  source: SkinBank.MAGATAMA_DIR + "0" + (config.heg ? '-heg' : '')
  state: "3"
  height: 19; fillMode: Image.PreserveAspectFit

  states: [
    State {
      name: "3"
      PropertyChanges {
        target: main
        source: SkinBank.MAGATAMA_DIR + "3" + (config.heg ? '-heg' : '')
        opacity: 1
        scale: 1
      }
    },
    State {
      name: "2"
      PropertyChanges {
        target: main
        source: SkinBank.MAGATAMA_DIR + "2" + (config.heg ? '-heg' : '')
        opacity: 1
        scale: 1
      }
    },
    State {
      name: "1"
      PropertyChanges {
        target: main
        source: SkinBank.MAGATAMA_DIR + "1" + (config.heg ? '-heg' : '')
        opacity: 1
        scale: 1
      }
    },
    State {
      name: "0"
      PropertyChanges {
        target: main
        source: SkinBank.MAGATAMA_DIR + "0" + (config.heg ? '-heg' : '')
        opacity: 0
        scale: 4
      }
    }
  ]

  transitions: Transition {
    PropertyAnimation {
      properties: "opacity,scale"
    }
  }

  Image {
    id: main
    anchors.centerIn: parent
    height: 19; fillMode: Image.PreserveAspectFit
  }
}
