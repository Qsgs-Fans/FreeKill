// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects
import Fk
import Fk.PhotoElement

/* Layout of general card:
 *      +--------+
 *kindom|wu  9999| <- hp
 *name -|s       |
 *      |q img   |
 *      |        |
 *      |        |
 *      +--------+
 * Inherit from CardItem to use common signal
 */

CardItem {
  property string kingdom
  property string subkingdom: "wei"
  property int hp
  property int maxHp
  property int shieldNum
  property int mainMaxHp
  property int deputyMaxHp
  property int inPosition: 0
  property string pkgName: ""
  property bool detailed: true
  property alias hasCompanions: companions.visible
  name: ""
  // description: Sanguosha.getGeneralDescription(name)
  suit: ""
  number: 0
  footnote: ""
  card.source: known ? SkinBank.getGeneralPicture(name)
                     : (SkinBank.GENERALCARD_DIR + 'card-back')
  glow.color: "white" //Engine.kingdomColor[kingdom]

  // FIXME: 藕！！
  property bool heg: name.startsWith('hs__') || name.startsWith('ld__') ||
                     name.includes('heg__')

  Image {
    source: known ? (SkinBank.GENERALCARD_DIR + "border") : ""
  }

  Image {
    scale: subkingdom ? 0.6 : 1
    width: 34; fillMode: Image.PreserveAspectFit
    transformOrigin: Item.TopLeft
    source: SkinBank.getGeneralCardDir(kingdom) + kingdom
    visible: detailed && known
  }

  Image {
    scale: 0.6; x: 9; y: 12
    transformOrigin: Item.TopLeft
    width: 34; fillMode: Image.PreserveAspectFit
    source: subkingdom ? SkinBank.getGeneralCardDir(subkingdom) + subkingdom
                       : ""
    visible: detailed && known
  }

  Row {
    x: 34
    y: 4
    spacing: 1
    visible: detailed && known && !heg
    Repeater {
      id: hpRepeater
      model: (!heg) ? ((hp > 5 || hp !== maxHp) ? 1 : hp) : 0
      Item {
        width: childrenRect.width
        height: childrenRect.height
        Image {
          source: SkinBank.getGeneralCardDir(kingdom) + kingdom + "-magatama"
        }
        Image {
          id: subkingdomMagatama
          visible: false
          source: subkingdom ? SkinBank.getGeneralCardDir(subkingdom) +
                               subkingdom + "-magatama" : ""
        }
        LinearGradient {
          id: subkingdomMask
          visible: false
          anchors.fill: subkingdomMagatama
          gradient: Gradient {
            GradientStop { position: 0.35; color: "transparent" }
            GradientStop { position: 0.50; color: "white" }
          }
        }
        OpacityMask {
          anchors.fill: subkingdomMagatama
          source: subkingdomMagatama
          maskSource: subkingdomMask
          visible: subkingdom
        }
      }
    }

    Text {
      visible: hp > 5 || hp !== maxHp
      text: hp === maxHp ? ("x" + hp) : (" " + hp + "/" + maxHp)
      color: "white"
      font.pixelSize: 14
      style: Text.Outline
      y: -6
    }
  }

  Row {
    x: 34
    y: 3
    spacing: 0
    visible: detailed && known && heg
    Repeater {
      id: hegHpRepeater
      model: heg ? ((hp > 7 || hp !== maxHp) ? 1 : Math.ceil(hp / 2)) : 0
      Item {
        width: childrenRect.width
        height: childrenRect.height
        Image {
          opacity: ((mainMaxHp < 0 || deputyMaxHp < 0) && (index * 2 + 1 === hp) && inPosition !== -1)
                    ? (inPosition === 0 ? 0.5 : 0) :1
          height: 12; fillMode: Image.PreserveAspectFit
          source: SkinBank.getGeneralCardDir(kingdom) + kingdom + "-magatama-l"
        }
        Image {
          x: 4.4
          opacity: (index + 1) * 2 <= hp ? (((mainMaxHp < 0 || deputyMaxHp < 0) && inPosition !== -1 && ((index + 1) * 2 === hp))
                    ? (inPosition === 0 ? 0.5 : 0) : 1) : 0
          height: 12; fillMode: Image.PreserveAspectFit
          source: {
            const k = subkingdom ? subkingdom : kingdom;
            SkinBank.getGeneralCardDir(k) + k + "-magatama-r"
          }
        }
      }
    }

    Text {
      visible: hp > 7 || hp !== maxHp
      text: hp === maxHp ? ("x" + hp / 2) : (" " + hp / 2 + "/" + maxHp / 2)
      color: "white"
      font.pixelSize: 14
      style: Text.Outline
      y: -4
    }
  }

  Shield {
    visible: shieldNum > 0 && detailed && known
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: hpRepeater.model > 4 ? 16 : 0
    scale: 0.8
    value: shieldNum
  }

  Image {
    id: companions
    width: parent.width
    fillMode: Image.PreserveAspectFit
    visible: false
    source: {
      const f = SkinBank.getGeneralCardDir(kingdom) + kingdom + "-companions";
      if (Backend.exists(f + ".png")) return f;
      return "";
    }
    anchors.horizontalCenter: parent.horizontalCenter
    y: 80
  }

  Text {
    width: 20
    height: 80
    x: 2
    y: lineCount > 6 ? 30 : 34
    text: name !== "" ? luatr(name) : "nil"
    visible: luatr(name).length <= 6 && detailed && known
    color: "white"
    font.family: fontLibian.name
    font.pixelSize: 18
    lineHeight: Math.max(1.4 - lineCount / 8, 0.6)
    style: Text.Outline
    wrapMode: Text.WrapAnywhere
  }

  Text {
    x: 0
    y: 12
    rotation: 90
    transformOrigin: Item.BottomLeft
    text: luatr(name)
    visible: luatr(name).length > 6 && detailed && known
    color: "white"
    font.family: fontLibian.name
    font.pixelSize: 18
    style: Text.Outline
  }

  Rectangle {
    visible: pkgName !== "" && detailed && known
    height: 16
    width: childrenRect.width + 4
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 4
    anchors.right: parent.right
    anchors.rightMargin: 4

    color: "#3C3229"
    opacity: 0.8
    radius: 4
    border.color: "white"
    border.width: 1
    Text {
      text: luatr(pkgName)
      x: 2; y: 1
      font.family: fontLibian.name
      font.pixelSize: 14
      color: "white"
      style: Text.Outline
      textFormat: Text.RichText
    }
  }

  onNameChanged: {
    const data = lcall("GetGeneralData", name);
    kingdom = data.kingdom;
    subkingdom = (data.subkingdom !== kingdom && data.subkingdom) || "";
    hp = data.hp;
    maxHp = data.maxHp;
    shieldNum = data.shield;
    mainMaxHp = data.mainMaxHpAdjustedValue;
    deputyMaxHp = data.deputyMaxHpAdjustedValue;

    const splited = name.split("__");
    if (splited.length > 1) {
      pkgName = splited[0];
    } else {
      pkgName = "";
    }
  }
}
