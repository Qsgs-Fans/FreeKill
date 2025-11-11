// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Components.GameCommon as Game
import Fk.Components.LunarLTK.Photo

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

Game.BasicCard {
  id: root
  width: 93
  height: 130

  property string name
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

  footnote: ""
  cardFrontSource: (Config.enabledSkins[name] && Config.enabledSkins[name] !== "-") ? Config.enabledSkins[name] : SkinBank.getGeneralPicture(name)
  cardBackSource: SkinBank.generalCardDir + 'card-back'
  glow.color: "white" //Engine.kingdomColor[kingdom]

  // FIXME: 藕！！
  property bool heg: name.startsWith('hs__') || name.startsWith('ld__') ||
                     name.includes('heg__')

  Image {
    source: parent.known ? (SkinBank.generalCardDir + "border") : ""
  }

  Image {
    scale: parent.subkingdom ? 0.6 : 1
    width: 34; fillMode: Image.PreserveAspectFit
    transformOrigin: Item.TopLeft
    source: SkinBank.getGeneralCardDir(parent.kingdom) + parent.kingdom
    visible: parent.detailed && parent.known
  }

  Image {
    scale: 0.6; x: 9; y: 12
    transformOrigin: Item.TopLeft
    width: 34; fillMode: Image.PreserveAspectFit
    source: parent.subkingdom ? SkinBank.getGeneralCardDir(parent.subkingdom) + parent.subkingdom
                       : ""
    visible: parent.detailed && parent.known
  }

  Row {
    x: 34
    y: 4
    spacing: 1
    visible: parent.detailed && parent.known && !parent.heg
    Repeater {
      id: hpRepeater
      model: (!root.heg) ? ((root.hp > 5 || root.hp !== root.maxHp) ? 1 : root.hp) : 0
      Item {
        width: childrenRect.width
        height: childrenRect.height
        Image {
          id: mainMagatama
          source: SkinBank.getGeneralCardDir(root.kingdom) + root.kingdom + "-magatama"
          visible: !root.subkingdom
        }
        LinearGradient {
          id: mainMagatamaMask
          visible: false
          anchors.fill: mainMagatama
          gradient: Gradient {
            GradientStop { position: 0.2; color: "white" }
            GradientStop { position: 0.8; color: "transparent" }
          }
        }
        OpacityMask {
          anchors.fill: mainMagatama
          source: mainMagatama
          maskSource: mainMagatamaMask
          visible: !!root.subkingdom
        }

        Image {
          id: subkingdomMagatama
          visible: false
          source: root.subkingdom ? SkinBank.getGeneralCardDir(root.subkingdom) +
                               root.subkingdom + "-magatama" : ""
        }
        LinearGradient {
          id: subkingdomMask
          visible: false
          anchors.fill: subkingdomMagatama
          gradient: Gradient {
            GradientStop { position: 0.2; color: "transparent" }
            GradientStop { position: 0.8; color: "white" }
          }
        }
        OpacityMask {
          anchors.fill: subkingdomMagatama
          source: subkingdomMagatama
          maskSource: subkingdomMask
          visible: root.subkingdom
        }
      }
    }

    Text {
      visible: root.hp > 5 || root.hp !== root.maxHp
      text: root.hp === root.maxHp ? ("x" + root.hp) : (" " + root.hp + "/" + root.maxHp)
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
    x: 3
    y: lineCount > 4 ? 30 : 34
    text: name !== "" ? Lua.tr(name) : "nil"
    visible: detailed && known
    color: "white"
    font.family: "LiSu"
    font.pixelSize: 18
    lineHeight: Math.max(1.4 - lineCount / 8, 0.8)
    style: Text.Outline
    wrapMode: Text.WrapAnywhere
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
      text: Lua.tr(pkgName)
      x: 2; y: 1
      font.family: Config.libianName
      font.pixelSize: 14
      color: "white"
      style: Text.Outline
      textFormat: Text.RichText
    }
  }

  onNameChanged: {
    const data = Lua.call("GetGeneralData", name);
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
