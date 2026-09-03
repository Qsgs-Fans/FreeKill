// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.GameCommon as Game
import Fk.Components.Common

import LunarLtk

pragma ComponentBehavior: Bound

/* Layout of card:
 *      +--------+
 * num -|5       |
 * suit-|s       |
 *      |  img   |
 *      |        |
 *      |footnote|
 *      +--------+
 */

Game.PokerCard {
  id: root
  width: 93 * cardScale
  height: 130 * cardScale

  required property CardModel dataModel
  onDataModelChanged: dataModel.cardItem = root;

  suit: dataModel.suit
  number: dataModel.number
  color: dataModel.color
  footnote: dataModel.footnote
  footnoteVisible: dataModel.footnoteVisible
  known: dataModel.known

  selectable: dataModel.selectable
  onSelectedChanged: dataModel.selected = selected;

  Connections {
    target: root.dataModel
    function onSelectedChanged() {
      if (root.selected !== root.dataModel.selected) {
        root.selected = root.dataModel.selected;
      }
    }
  }

  property bool markVisible: dataModel.markVisible
  property string areaText: "" // 手牌中用来显示“装备区”、“木牛”等

  hoverHandler.cursorShape: selectable ? Qt.PointingHandCursor : Qt.ArrowCursor

  property bool showDetail: true
  onRightClicked: {
    if (!showDetail || !known) return;
    roomScene.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "CardDetail"), { cardId: dataModel.cardId });
  }

  cardFrontSource: {
    const picName = dataModel.picName
    if (picName) {
      if (picName.startsWith("general:")) 
        return SkinBank.getGeneralPicture(picName.substring(8));
      if (picName.startsWith("path:"))
        return Cpp.path + "/" + picName.substring(5);
      return SkinBank.getCardPicture(picName);
    }
    return SkinBank.getCardPicture(dataModel.cardId || dataModel.name)
  }
  cardBackSource: SkinBank.searchBuiltinPic("/image/card/", "card-back")

  Rectangle {
    id: virt_rect
    visible: root.known && root.dataModel.virtName && root.dataModel.virtName !== root.dataModel.name
    width: parent.width
    height: 20 * root.cardScale
    y: 40 * root.cardScale
    color: "snow"
    opacity: 0.8
    radius: 4 * root.cardScale
    border.color: "black"
    border.width: 1

    Text {
      anchors.centerIn: parent
      font.pixelSize: Math.floor(16 * root.cardScale)
      font.family: Config.libianName
      font.letterSpacing: -0.6
      text: Lua.tr(root.dataModel.virtName)
    }
  }

  Component {
    id: cardMarkDelegate
    Item {
      required property var modelData
      visible: root.known || modelData.origName.includes("-public")
      width: root.width - 2
      x: 1
      height: {
        let markLength = root.dataModel.marks.length ?? 0;
        if (markLength <= 4) return 16 * root.cardScale;
        else return Math.floor(70 / markLength * root.cardScale);
      }
      Rectangle {
        width: parent.width
        height: parent.height
        color: "#ddf0ebd1"
        radius: 2 * root.cardScale
        border.color: "snow"
        border.width: Math.ceil(1 * root.cardScale)
      }
      Text {
        id: markText
        anchors.centerIn: parent
        font.pixelSize: Math.floor(12 * root.cardScale)
        font.letterSpacing: -0.6
        text: {
          const data = parent.modelData;
          if (!data) return "";
          return `${data.name} ${data.value}`.trim();
        }
        color: "#554B3F"
        transform: Scale {
          origin.x: markText.width / 2
          origin.y: markText.height / 2
          xScale: markText.width > (root.width-4) ? ((root.width-4) / markText.width) : 1
        }
      }
    }
  }

  Column {
    width: root.width
    y: 60 * root.cardScale
    visible: root.known && root.markVisible
    Repeater {
      model: root.dataModel.marks
      delegate: cardMarkDelegate
    }
  }

  Text {
    id: prohibitText
    visible: !root.selectable && root.known
    anchors.centerIn: parent
    font.family: Config.libianName
    font.pixelSize: Math.floor(18 * root.cardScale)
    opacity: 0.9
    horizontalAlignment: Text.AlignHCenter
    lineHeight: 18 * root.cardScale
    lineHeightMode: Text.FixedHeight
    color: "snow"
    width: 20 * root.cardScale
    wrapMode: Text.WrapAnywhere
    style: Text.Outline
    styleColor: "red"
    text: root.dataModel.prohibitReason
  }

  Rectangle {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 4
    x: 1

    visible: root.areaText !== ""
    width: childrenRect.width + 12
    height: 18
    color: "#f2e286"
    border.color: "#820307"
    border.width: 1

    Text {
      text: Lua.tr(root.areaText)
      x: 6
      y: 1
      font.family: Config.libianName
      font.pixelSize: 16
      font.bold: true
      color: "#820327"
      textFormat: Text.RichText
    }
  }

  RowLayout {
    anchors.centerIn: parent
    spacing: 5

    Repeater {
      model: root.dataModel.cardTip

      Item {
        required property var modelData
        // Layout.alignment: Qt.AlignHCenter
        width: modelData.type === "normal" ? 30 : 18

        GlowText {
          anchors.centerIn: parent
          visible: parent.modelData.type === "normal"
          text: parent.modelData.content
          font.family: Config.li2Name
          color: "#FEFE84"
          font.pixelSize: {
            if (text.length <= 3) return 27;
            else return 21;
          }
          //font.bold: true
          glow.color: "black"
          glow.spread: 0.3
          glow.radius: 4
          lineHeight: 0.85
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WrapAnywhere
          width: font.pixelSize + 4
        }

        Text {
          anchors.centerIn: parent
          visible: parent.modelData.type === "warning"
          font.family: Config.libianName
          font.pixelSize: 18
          opacity: 0.9
          horizontalAlignment: Text.AlignHCenter
          lineHeight: 18
          lineHeightMode: Text.FixedHeight
          //color: "#EAC28A"
          color: "snow"
          width: 18
          wrapMode: Text.WrapAnywhere
          style: Text.Outline
          //styleColor: "#83231F"
          styleColor: "red"
          text: parent.modelData.content
        }
      }
    }
  }

}
