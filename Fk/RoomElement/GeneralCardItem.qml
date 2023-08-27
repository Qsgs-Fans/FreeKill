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
  property string pkgName: ""
  property bool detailed: true
  name: ""
  // description: Sanguosha.getGeneralDescription(name)
  suit: ""
  number: 0
  footnote: ""
  card.source: SkinBank.getGeneralPicture(name)
  glow.color: "white" //Engine.kingdomColor[kingdom]

  Image {
    source: SkinBank.GENERALCARD_DIR + "border"
  }

  Image {
    scale: subkingdom ? 0.6 : 1
    transformOrigin: Item.TopLeft
    source: SkinBank.getGeneralCardDir(kingdom) + kingdom
    visible: detailed
  }

  Image {
    scale: 0.6; x: 9; y: 12
    transformOrigin: Item.TopLeft
    source: subkingdom ? SkinBank.getGeneralCardDir(subkingdom) + subkingdom : ""
    visible: detailed
  }

  Row {
    x: 34
    y: 4
    spacing: 1
    visible: detailed
    Repeater {
      id: hpRepeater
      model: (hp > 5 || hp !== maxHp) ? 1 : hp
      Item {
        width: childrenRect.width
        height: childrenRect.height
        Image {
          source: SkinBank.getGeneralCardDir(kingdom) + kingdom + "-magatama"
        }
        Image {
          id: subkingdomMagatama
          visible: false
          source: subkingdom ? SkinBank.getGeneralCardDir(subkingdom) + subkingdom + "-magatama" : ""
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

  Shield {
    visible: detailed
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: hpRepeater.model > 4 ? 16 : 0
    scale: 0.8
    value: shieldNum
  }

  Text {
    width: 20
    height: 80
    x: 2
    y: lineCount > 6 ? 30 : 34
    text: Backend.translate(name)
    visible: Backend.translate(name).length <= 6 && detailed
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
    text: Backend.translate(name)
    visible: Backend.translate(name).length > 6 && detailed
    color: "white"
    font.family: fontLibian.name
    font.pixelSize: 18
    style: Text.Outline
  }

  Rectangle {
    visible: pkgName !== "" && detailed
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
      text: Backend.translate(pkgName)
      x: 2; y: 1
      font.family: fontLibian.name
      font.pixelSize: 14
      color: "white"
      style: Text.Outline
      textFormat: Text.RichText
    }
  }

  onNameChanged: {
    const data = JSON.parse(Backend.callLuaFunction("GetGeneralData", [name]));
    kingdom = data.kingdom;
    subkingdom = (data.subkingdom !== kingdom && data.subkingdom) || "";
    hp = data.hp;
    maxHp = data.maxHp;
    shieldNum = data.shield;

    const splited = name.split("__");
    if (splited.length > 1) {
      pkgName = splited[0];
    } else {
      pkgName = "";
    }
  }
}
