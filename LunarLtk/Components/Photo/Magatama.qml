// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk

Image {
  source: SkinBank.magatamaDir + "0" + (Config.heg ? '-heg' : '')
  state: "3"
  height: 14; fillMode: Image.PreserveAspectFit

  states: [
    State {
      name: "3"
      PropertyChanges {
        target: main
        source: SkinBank.magatamaDir + "3" + (Config.heg ? '-heg' : '')
        opacity: 1
        scale: 1
      }
    },
    State {
      name: "2"
      PropertyChanges {
        target: main
        source: SkinBank.magatamaDir + "2" + (Config.heg ? '-heg' : '')
        opacity: 1
        scale: 1
      }
    },
    State {
      name: "1"
      PropertyChanges {
        target: main
        source: SkinBank.magatamaDir + "1" + (Config.heg ? '-heg' : '')
        opacity: 1
        scale: 1
      }
    },
    State {
      name: "0"
      PropertyChanges {
        target: main
        source: SkinBank.magatamaDir + "0" + (Config.heg ? '-heg' : '')
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
    height: 14; fillMode: Image.PreserveAspectFit
  }
}
