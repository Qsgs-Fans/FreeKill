// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Components.GameCommon as Game
import LunarLtk
import LunarLtk.Components.Photo

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

  required property GeneralCardModel dataModel
  onDataModelChanged: dataModel.cardItem = root;

  footnote: dataModel.footnote
  cardFrontSource: dataModel.frontSkin
  cardBackSource: dataModel.backSkin
  glow.color: "white" //Engine.kingdomColor[kingdom]
  cardBg.pause: dataModel.pause

  known: dataModel.known

  Image {
    anchors.fill: parent
    anchors.margins: -1
    fillMode: Image.PreserveAspectFit
    source: parent.dataModel.known ? (SkinBank.generalCardDir + "border") : ""
  }

  Image {
    scale: parent.dataModel.subkingdom ? 0.6 : 1
    width: 34; fillMode: Image.PreserveAspectFit
    anchors.top: parent.top
    anchors.topMargin: parent.dataModel.subkingdom ? -7 : -2
    anchors.left: parent.left
    anchors.leftMargin: parent.dataModel.subkingdom ? -8 : -2
    source: {
      if (parent.dataModel.kingdom) {
        return SkinBank.getGeneralCardDir(parent.dataModel.kingdom) + parent.dataModel.kingdom;
      }
      return "";
    }
    visible: parent.dataModel.detailed && parent.dataModel.known
  }

  Image {
    scale: 0.6; x: 8; y: 12
    transformOrigin: Item.TopLeft
    width: 34; fillMode: Image.PreserveAspectFit
    source: {
      if (parent.dataModel.subkingdom) {
        return SkinBank.getGeneralCardDir(parent.dataModel.subkingdom) + parent.dataModel.subkingdom;
      }
      return "";
    }
    visible: parent.dataModel.detailed && parent.dataModel.known
  }

  Component {
    id: duelkingdomMagatama
    Item {
      width: 10
      height: 10 / childrenRect.width * childrenRect.height
      Image {
        id: mainMagatama
        source: SkinBank.getGeneralCardDir(root.dataModel.kingdom) + root.dataModel.kingdom + "-magatama"
        width: 10
        height: 10 / sourceSize.width * sourceSize.height
        visible: !root.dataModel.subkingdom
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
        visible: !!root.dataModel.subkingdom
      }

      Image {
        id: subkingdomMagatama
        visible: false
        width: 10
        height: 10 / sourceSize.width * sourceSize.height
        source: {
          if (root.dataModel.subkingdom) {
            return SkinBank.getGeneralCardDir(root.dataModel.subkingdom) +
                                root.dataModel.subkingdom + "-magatama";
          }
          return "";
        }
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
        visible: root.dataModel.subkingdom
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
        source: {
          if (root.dataModel.kingdom) {
            return SkinBank.getGeneralCardDir(root.dataModel.kingdom) +
                                root.dataModel.kingdom + "-magatama";
          }
          return "";
        }
        width: 10
        height: 10 / sourceSize.width * sourceSize.height
      }
    }
  }

  Row {
    id: magatamaRow
    x: 34; y: 4
    spacing: 1
    visible: parent.dataModel.detailed && parent.dataModel.known && !parent.dataModel.heg
    Repeater {
      id: hpRepeater
      model: (!root.dataModel.heg) ? ((root.dataModel.hp > 5 || root.dataModel.hp !== root.dataModel.maxHp) ? 1 : root.dataModel.hp) : 0
      delegate: root.dataModel.subkingdom ? duelkingdomMagatama : singlekingdomMagatama
    }
  }

  Text {
    anchors.left: magatamaRow.right
    anchors.leftMargin: -1
    visible: (parent.dataModel.hp ?? 0) > 5 || parent.dataModel.hp !== parent.dataModel.maxHp
    text: parent.dataModel.hp === parent.dataModel.maxHp ? (" x" + parent.dataModel.hp) : (" " + parent.dataModel.hp + "/" + parent.dataModel.maxHp)
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
    visible: parent.dataModel.detailed && parent.dataModel.known && parent.dataModel.heg
    Repeater {
      id: hegHpRepeater
      model: root.dataModel.heg ? ((root.dataModel.hp > 7 || root.dataModel.hp !== root.dataModel.maxHp) ? 1 : Math.ceil(root.dataModel.hp / 2)) : 0
      Item {
        width: childrenRect.width
        height: childrenRect.height
        required property int index
        Image {
          opacity: ((root.dataModel.mainMaxHp < 0 || root.dataModel.deputyMaxHp < 0) && (index * 2 + 1 === root.dataModel.hp) && root.dataModel.inPosition !== -1)
                    ? (root.dataModel.inPosition === 0 ? 0.5 : 0) :1
          height: 12; fillMode: Image.PreserveAspectFit
          source: SkinBank.getGeneralCardDir(root.dataModel.kingdom) + root.dataModel.kingdom + "-magatama-l"
        }
        Image {
          x: 4.4
          opacity: (index + 1) * 2 <= root.dataModel.hp ? (((root.dataModel.mainMaxHp < 0 || root.dataModel.deputyMaxHp < 0) && root.dataModel.inPosition !== -1 && ((index + 1) * 2 === root.dataModel.hp))
                    ? (root.dataModel.inPosition === 0 ? 0.5 : 0) : 1) : 0
          height: 12; fillMode: Image.PreserveAspectFit
          source: {
            const k = root.dataModel.subkingdom ? root.dataModel.subkingdom : root.dataModel.kingdom;
            SkinBank.getGeneralCardDir(k) + k + "-magatama-r"
          }
        }
      }
    }

    Text {
      visible: root.dataModel.hp > 7 || root.dataModel.hp !== root.dataModel.maxHp
      text: root.dataModel.hp === root.dataModel.maxHp ? ("x" + root.dataModel.hp / 2) : (" " + root.dataModel.hp / 2 + "/" + root.dataModel.maxHp / 2)
      color: "white"
      font.pixelSize: 14
      style: Text.Outline
      y: -4
    }
  }

  Shield {
    visible: parent.dataModel.shieldNum > 0 && parent.dataModel.detailed && parent.dataModel.known
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: hpRepeater.model > 4 ? 16 : 0
    scale: 0.8
    value: parent.dataModel.shieldNum
  }

  Image {
    id: companions
    width: parent.width
    fillMode: Image.PreserveAspectFit
    visible: parent.dataModel.hasCompanion
    source: {
      const f = SkinBank.getGeneralCardDir(parent.dataModel.kingdom) + parent.dataModel.kingdom + "-companions";
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
    text: parent.dataModel && parent.dataModel.name !== "" ? Lua.tr(parent.dataModel.name) : "nil"
    visible: parent.dataModel.detailed && parent.dataModel.known
    color: "white"
    font.family: "LiSu"
    font.pixelSize: 18
    lineHeight: Math.max(1.25 - lineCount / 8, 0.8)
    style: Text.Outline
    wrapMode: Text.WrapAnywhere
  }

  Rectangle {
    visible: parent.dataModel.detailed && parent.dataModel.prefix !== "" && parent.dataModel.known
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
      text: root.dataModel.prefix
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
    visible: Config.favoriteGenerals.includes(parent.dataModel.name) && parent.dataModel.showIsFavorite
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
}
