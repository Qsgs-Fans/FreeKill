// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.Common
import LunarLtk

Column {
  id: root

  required property PhotoModel dataModel
  property var colors: ["#F4180E", "#F4180E", "#E3B006", "#25EC27"]

  Shield {
    id: shield
    value: root.dataModel.shield
  }

  Repeater {
    id: repeater
    model: column.visible ? 0 : root.dataModel.maxHp
    Magatama {
      state: {
        const value = root.dataModel.hp;
        const maxValue = root.dataModel.maxHp;
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
    visible: {
      const maxHp = root.dataModel.maxHp;
      const hp = root.dataModel.maxHp;
      const shield = root.dataModel.shield;
      return maxHp > 4 || hp > maxHp || (shield > 0 && maxHp > 3)
    }
    spacing: -4

    Magatama {
      state: {
        const maxHp = root.dataModel.maxHp;
        const hp = root.dataModel.hp;
        return (hp >= 3 || hp >= maxHp) ? 3 : (hp <= 0 ? 0 : hp)
      }
    }

    GlowText {
      id: hpItem
      width: root.width
      text: root.dataModel.hp
      color: {
        let idx;
        const hp = root.dataModel.hp;
        const maxHp = root.dataModel.maxHp;
        if (hp >= 3 || hp >= maxHp) {
          idx = 3;
        } else if (hp <= 0) {
          idx = 0;
        } else {
          idx = hp;
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
      text: root.dataModel.maxHp
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
