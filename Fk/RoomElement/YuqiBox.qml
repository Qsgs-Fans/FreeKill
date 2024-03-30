// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import Fk.Pages

GraphicsBox {
  id: root

  title.text: ""

  // TODO: Adjust the UI design in case there are more than 7 cards
  width: 70 + 1000
  height: 64 + Math.min(cardView.contentHeight, 400) + 30

  signal cardsSelected(var ids)
  property string Yuqi_type
  property var card_data
  property bool cancelable: true
  property var extra_data

  ListModel {
    id: cardModel
  }

  ListView {
    id: cardView
    anchors.fill: parent
    anchors.topMargin: 40
    anchors.leftMargin: 20
    anchors.rightMargin: 20
    anchors.bottomMargin: 30
    spacing: 20
    model: cardModel
    clip: true

    delegate: RowLayout {
      spacing: 15
      // visible: areaCards.count > 0

      Rectangle {
        border.color: "#A6967A"
        radius: 5
        color: "transparent"
        width: 18
        height: 130
        Layout.alignment: Qt.AlignTop

        Text {
          color: "#E4D5A0"
          text: luatr(areaName)
          anchors.fill: parent
          wrapMode: Text.WrapAnywhere
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 15
        }
      }

      Rectangle {
        id: cardsArea
        color: "#1D1E19"
        width: 800
        height: 130
      }
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

  Repeater {
    id: citem
    model: cards

    CardItem {
      x: index
      y: -1
      cid: modelData.cid
      name: modelData.name
      suit: modelData.suit
      number: modelData.number
      draggable: true
      onReleased: updateCardReleased(this);
    }
  }



  function findAreaModel(name) {
    let ret;
    for (let i = 0; i < cardModel.count; i++) {
      let item = cardModel.get(i);
      if (item.areaName === name) {
        ret = item;
        break;
      }
    }
    if (!ret) {
      ret = {
        areaName: name,
        areaCards: [],
      }
      cardModel.append(ret);
      ret = findAreaModel(name);
    }
    return ret;
  }

  function findAllModel() {
    let ret = [];
    for (let i = 0; i < cardModel.count; i++) {
      let item = cardModel.get(i);
      ret.push([item.areaName, item.areaCards]);
    }
    return ret;
  }

  function addCustomCards(name, cards) {
    let area = findAreaModel(name).areaCards;
    if (cards instanceof Array) {
      for (let i = 0; i < cards.length; i++)
        area.append(cards[i]);
    } else {
      area.append(cards);
    }
  }

  function arrangeCards() {
  }

  function refreshPrompt() {
    root.title.text = Util.processPrompt(lcall("YuqiPrompt", Yuqi_type, card_data, extra_data))
  }
}
