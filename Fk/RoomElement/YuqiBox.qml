// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import Fk.Pages

GraphicsBox {
  id: root
  property string Yuqi_type
  property var cards: [] //全体卡牌枚举
  property var result: [] //最终牌堆
  property var pilecards: [] //初始牌堆
  property var areaNames: [] //牌堆名
  property bool cancelable: true
  property var extra_data
  property int padding: 25

  title.text: ""

  width: body.width + padding * 2
  height: title.height + body.height + padding * 2

  ColumnLayout {
    id: body
    x: padding
    y: parent.height - padding - height
    spacing: 10

    Repeater {
      id: areaRepeater
      model: pilecards

      Row {
        spacing: 5

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          color: "#6B5D42"
          width: 20
          height: 100
          radius: 5

          Text {
            anchors.fill: parent
            width: 20
            height: 100
            text: areaNames.length > index ? qsTr(areaNames[index]) : ""
            color: "white"
            font.family: fontLibian.name
            font.pixelSize: 18
            style: Text.Outline
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
          }
        }

        Rectangle {
          id: cardsArea
          color: "#1D1E19"
          width: 800
          height: 130

        }
        // property alias cardsArea: cardsArea
      }
    }

    Row {
      anchors.margins: 8
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 32

      MetroButton {
        width: 120
        height: 35
        text: luatr("OK")
        enabled: lcall("YuqiFeasible", root.Yuqi_type, root.selected_ids,
                      root.card_data, root.extra_data);
        onClicked: root.cardsSelected(findAllModel())
      }

      MetroButton {
        width: 120
        height: 35
        text: luatr("Cancel")
        visible: root.cancelable
        onClicked: root.cardsSelected(card_data)
      }

    }
  }

  Repeater {
    id: cardItem
    model: cards

    CardItem {
      x: index
      y: -1
      cid: modelData.cid
      name: modelData.name
      suit: modelData.suit
      number: modelData.number
      draggable: true
      onReleased: updateCardsReleased();
    }
  }

  function updateCardsReleased() {
    for (i = 0; i < cardItem.count; i++) {
      _card = result[0][i]
      if (Math.abs(card.x - _card.x) <= 50) {
        result[1][result[1].indexOf(card)] = _card;
        result[0][i] = card;
        break;
      }
    }
    arrangeCards();
  }

  function arrangeCards() {
    let i, j;
    let card, box, pos, pile;
    let spacing
    for (j = 0; j < pilecards.length; j++){
      pile = areaRepeater.itemAt(j);
      if (pile.y === 0){
        pile.y = j * 150
      }
      spacing = (result[j].length > 8) ? (700 / (result[j].length - 1)) : 100
      for (i = 0; i < result[j].length; i++) {
        box = pile.cardsArea;
        pos = mapFromItem(pile, box.x, box.y);
        card = result[j][i];
        card.draggable = (j > 0)
        card.origX = pos.x + i * spacing;
        card.origY = pos.y;
        card.z = i + 1;
        card.initialZ = i + 1;
        card.maxZ = result[j].length;
        card.goBack(true);
      }
    }
    refreshPrompt();
  }

  function refreshPrompt() {
    root.title.text = Util.processPrompt(lcall("YuqiPrompt", Yuqi_type, card_data, extra_data))
  }
}
