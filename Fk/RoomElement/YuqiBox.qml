// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk.Pages

GraphicsBox {
  id: root
  property string prompt
  property var data
  property var old_cards: []
  property var cards: []
  property var areaNames: []
  property int length: 1
  property var extra_data
  property bool cancelable: true
  property string yuqi_type
  property int padding: 25

  signal returnResults(var ids)

  title.text: Backend.callLuaFunction("YuqiPrompt", [yuqi_type, data, extra_data])
  width: body.width + padding * 2
  height: title.height + body.height + padding * 2

  ColumnLayout {
    id: body
    x: padding
    y: parent.height - padding - height
    spacing: 20

    Repeater {
      id: areaRepeater
      model: old_cards

      Row {
        spacing: 5

        property int areaCapacity: modelData
        property string areaName: index < data.length ? qsTr(areaNames.name[index]) : ""

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
            text: Backend.translate(areaName)
            color: "white"
            font.family: fontLibian.name
            font.pixelSize: 18
            style: Text.Outline
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
          }
        }

        Repeater {
          id: cardRepeater
          model: areaCapacity

          Rectangle {
            color: "#1D1E19"
            width: 93
            height: 130

            Text {
              anchors.centerIn: parent
              text: Backend.translate(areaName)
              color: "#59574D"
              width: parent.width * 0.8
              wrapMode: Text.WordWrap
            }
          }
        }
        property alias cardRepeater: cardRepeater
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
        text: Backend.translate("OK")
        enabled: {
          return JSON.parse(Backend.callLuaFunction(
            "YuqiFeasible",
            [root.yuqi_type, root.cards, root.data, root.extra_data]
          ));
        }
        onClicked: root.getResult(true);
      }

      MetroButton {
        width: 120
        height: 35
        text: Backend.translate("Cancel")
        enabled: root.cancelable
        onClicked: root.getResult(false);
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
      draggable: {
          return JSON.parse(Backend.callLuaFunction(
            "YuqiOutFilter",
            [root.yuqi_type, model.cid, root.cards, root.extra_data]
          ));
        }
      onReleased: arrangeCards(model.cid);
    }
  }

  function arrangeCards(var moved_card) {
    let pos;
    for (i = 0; i < cards.length; i++) {
      let pile = cards[i];
      if (moved_card != null) {
        if (pile[j] == moved_card) 
      }
      for (j = 0; j < pile.length; j++) {
      }
    }


    let box, pos, pile;
    for (j = 0; j < areaRepeater.count; j++) {
      pile = areaRepeater.itemAt(j);
      if (pile.y === 0){
        pile.y = j * 150
      }
      for (i = 0; i < result[j].length; i++) {
        box = pile.cardRepeater.itemAt(i);
        pos = mapFromItem(pile, box.x, box.y);
        card = result[j][i];
        card.origX = pos.x;
        card.origY = pos.y;
        card.goBack(true);
      }
    }
  }

  function getResult(var bol) {
    if (!bol) return old_cards;
    return cards;
  }
}
