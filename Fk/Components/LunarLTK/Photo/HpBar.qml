// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.Common
import Fk.Components.LunarLTK

Column {
  id: root
  property int maxValue: 4
  property int value: 4
  property var colors: ["#F4180E", "#F4180E", "#E3B006", "#25EC27"]
  property int shieldNum: 0

  Shield {
    id: shield
    value: shieldNum
  }

  Repeater {
    id: repeater
    model: column.visible ? 0 : maxValue
    Magatama {
      state: {
        if (maxValue - 1 - index >= value) {
          return 0;
        } else if (value >= 3 || value >= maxValue) {
          return 3;
        } else if (value <= 0) {
          return 0;
        } else {
          return value;
        }
      }
    }
  }

  Column {
    id: column
    visible: maxValue > 4 || value > maxValue ||
             (shieldNum > 0 && maxValue > 3)
    spacing: -4

    Magatama {
      state: (value >= 3 || value >= maxValue) ? 3 : (value <= 0 ? 0 : value)
    }

    GlowText {
      id: hpItem
      width: root.width
      text: value
      color: {
        let idx;
        if (value >= 3 || value >= maxValue) {
          idx = 3;
        } else if (value <= 0) {
          idx = 0;
        } else {
          idx = value;
        }
        return root.colors[idx];
      }
      font.family: Config.libianName
      font.pixelSize: 16
      font.bold: true
      horizontalAlignment: Text.AlignHCenter

      glow.color: "#3E3F47"
      glow.spread: 0.8
      glow.radius: 6
      //glow.samples: 12
    }

    GlowText {
      id: splitter
      height: 12
      width: root.width
      text: "/"
      z: -10
      rotation: 40
      color: hpItem.color
      font.family: Config.libianName
      font.pixelSize: 14
      font.bold: true
      horizontalAlignment: hpItem.horizontalAlignment

      glow.color: hpItem.glow.color
      glow.spread: hpItem.glow.spread
      glow.radius: hpItem.glow.radius
      //glow.samples: hpItem.glow.samples
    }

    GlowText {
      id: maxHpItem
      width: root.width
      text: maxValue
      color: hpItem.color
      font: hpItem.font
      horizontalAlignment: hpItem.horizontalAlignment

      glow.color: hpItem.glow.color
      glow.spread: hpItem.glow.spread
      glow.radius: hpItem.glow.radius
      //glow.samples: hpItem.glow.samples
    }
  }
}
