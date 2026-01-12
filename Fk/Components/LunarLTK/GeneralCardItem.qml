// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Components.GameCommon as Game
import Fk.Components.LunarLTK
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
  property bool showIsFavorite: true
  property alias hasCompanions: companions.visible

  footnote: ""
  cardFrontSource: (Config.enabledSkins[name] && Config.enabledSkins[name] !== "-") ? Config.enabledSkins[name] : SkinBank.getGeneralPicture(name)
  cardBackSource: SkinBank.generalCardDir + 'card-back'
  glow.color: "white" //Engine.kingdomColor[kingdom]

  // FIXME: 藕！！
  property bool heg: name.startsWith('hs__') || name.startsWith('ld__') ||
                     name.includes('heg__')

  Image {
    anchors.fill: parent
    anchors.margins: -1
    fillMode: Image.PreserveAspectFit
    source: parent.known ? (SkinBank.generalCardDir + "border") : ""
  }

  Image {
    scale: parent.subkingdom ? 0.6 : 1
    width: 34; fillMode: Image.PreserveAspectFit
    anchors.top: parent.top
    anchors.topMargin: parent.subkingdom ? -7 : -2
    anchors.left: parent.left
    anchors.leftMargin: parent.subkingdom ? -8 : -2
    source: SkinBank.getGeneralCardDir(parent.kingdom) + parent.kingdom
    visible: parent.detailed && parent.known
  }

  Image {
    scale: 0.6; x: 8; y: 12
    transformOrigin: Item.TopLeft
    width: 34; fillMode: Image.PreserveAspectFit
    source: parent.subkingdom ? SkinBank.getGeneralCardDir(parent.subkingdom) + parent.subkingdom
                       : ""
    visible: parent.detailed && parent.known
  }

  Component {
    id: duelkingdomMagatama
    Item {
      width: 10
      height: 10 / childrenRect.width * childrenRect.height
      Image {
        id: mainMagatama
        source: SkinBank.getGeneralCardDir(root.kingdom) + root.kingdom + "-magatama"
        width: 10
        height: 10 / sourceSize.width * sourceSize.height
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
        width: 10
        height: 10 / sourceSize.width * sourceSize.height
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

  Component {
    id: singlekingdomMagatama
    Item {
      width: childrenRect.width
      height: childrenRect.height
      Image {
        id: singleMagatamaImg
        source: SkinBank.getGeneralCardDir(root.kingdom) + root.kingdom + "-magatama"
        width: 10
        height: 10 / sourceSize.width * sourceSize.height
      }
    }
  }

  Row {
    id: magatamaRow
    x: 34; y: 4
    spacing: 1
    visible: parent.detailed && parent.known && !parent.heg
    Repeater {
      id: hpRepeater
      model: (!root.heg) ? ((root.hp > 5 || root.hp !== root.maxHp) ? 1 : root.hp) : 0
      delegate: root.subkingdom ? duelkingdomMagatama : singlekingdomMagatama
    }
  }

  Text {
    anchors.left: magatamaRow.right
    anchors.leftMargin: -1
    visible: root.hp > 5 || root.hp !== root.maxHp
    text: root.hp === root.maxHp ? (" x" + root.hp) : (" " + root.hp + "/" + root.maxHp)
    color: "white"
    font.family: Config.libianName
    font.pixelSize: 14
    font.bold: true
    style: Text.Outline
    y: 1
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
  
  Glow {
    source: generalName
    anchors.fill: generalName
    color: "black"
    spread: 0.3
    radius: 5
  }

  Text {
    id: generalName
    width: 20
    height: 80
    x: 3
    y: lineCount > 4 ? 28 : 30
    text: name !== "" ? Lua.tr(name) : "nil"
    visible: detailed && known
    color: "white"
    font.family: "LiSu"
    font.pixelSize: 18
    lineHeight: Math.max(1.25 - lineCount / 8, 0.8)
    style: Text.Outline
    wrapMode: Text.WrapAnywhere
  }

  Rectangle {
    visible: pkgName !== "" && detailed && known
    height: 16
    width: pkgNameText.width + 15
    anchors.bottom: parent.bottom
    anchors.right: parent.right

    color: "transparent"

    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop {
        position: 0
        color: Qt.rgba(0, 0, 0, 0)
      }
      GradientStop {
        position: 0.35
        color: Qt.rgba(0, 0, 0, 0.5)
      }
      GradientStop {
        position: 1
        color: Qt.rgba(0, 0, 0, 1)
      }
    }
    Text {
      id: pkgNameText
      text: Lua.tr(pkgName)
      x: 13; y: 1
      font.family: Config.libianName
      font.pixelSize: 14
      color: "white"
      style: Text.Outline
      textFormat: Text.RichText
      width: implicitWidth
    }
  }

  Item {
    visible: Config.favoriteGenerals.includes(parent.name) && parent.showIsFavorite
    width: 15; height: 15
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.margins: 1
    Canvas {
      id: starCanvas
      anchors.fill: parent
      onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var cx = width/2;
        var cy = height/2;
        var spikes = 5;
        var outerRadius = Math.min(width, height) * 0.45;
        var innerRadius = outerRadius * 0.45;
        var rot = -Math.PI/2; // start at top
        ctx.beginPath();
        for (var i = 0; i < spikes; i++) {
          var x = cx + Math.cos(rot) * outerRadius;
          var y = cy + Math.sin(rot) * outerRadius;
          ctx.lineTo(x, y);
          rot += Math.PI / spikes;

          x = cx + Math.cos(rot) * innerRadius;
          y = cy + Math.sin(rot) * innerRadius;
          ctx.lineTo(x, y);
          rot += Math.PI / spikes;
        }
        ctx.closePath();
        ctx.fillStyle = "red";
        ctx.fill();
        ctx.lineWidth = 1;
        ctx.strokeStyle = "white";
        ctx.stroke();
      }
      Component.onCompleted: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
    }
  }

  onNameChanged: {
    const data = Ltk.getGeneralData(name);
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
