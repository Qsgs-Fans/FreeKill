// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk.Pages

GraphicsBox {
  id: root
  property var cards: []
  property var result: []
  property var areaCapacities: []
  property var areaLimits: []
  property var areaNames: []
  property int padding: 25

  title.text: Backend.translate("Please arrange cards")
  width: body.width + padding * 2
  height: title.height + body.height + padding * 2

  ColumnLayout {
    id: body
    x: padding
    y: parent.height - padding - height
    spacing: 20

    Repeater {
      id: areaRepeater
      model: areaCapacities

      Row {
        spacing: 5

        property int areaCapacity: modelData
        property string areaName: index < areaNames.length ? qsTr(areaNames[index]) : ""

        Repeater {
          id: cardRepeater
          model: areaCapacity

          Rectangle {
            color: "#1D1E19"
            width: 93
            height: 130

            Text {
              anchors.centerIn: parent
              text: areaName
              color: "#59574D"
              width: parent.width * 0.8
              wrapMode: Text.WordWrap
            }
          }
        }
        property alias cardRepeater: cardRepeater
      }
    }

    MetroButton {
      Layout.alignment: Qt.AlignHCenter
      id: buttonConfirm
      text: Backend.translate("OK")
      width: 120
      height: 35

      onClicked: close();
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
      onReleased: arrangeCards();
    }
  }

  function arrangeCards() {
    result = new Array(areaCapacities.length);
    let i;
    for (i = 0; i < result.length; i++){
      result[i] = [];
    }

    let card, j, area, cards, stay;
    for (i = 0; i < cardItem.count; i++) {
      card = cardItem.itemAt(i);

      stay = true;
      for (j = areaRepeater.count - 1; j >= 0; j--) {
        area = areaRepeater.itemAt(j);
        cards = result[j];
        if (cards.length < areaCapacities[j] && card.y >= area.y) {
          cards.push(card);
          stay = false;
          break;
        }
      }

      if (stay) {
        for (j = 0; j < areaRepeater.count; j++) {
          if (result[j].length < areaCapacities[j]) {
            result[j].push(card);
            break;
          }
        }
      }
    }
    for(i = 0; i < result.length; i++)
      result[i].sort((a, b) => a.x - b.x);



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

    for (i = 0; i < areaRepeater.count; i++) {
      if (result[i].length < areaLimits[i]) {
        buttonConfirm.enabled = false;
        break;
      }
      buttonConfirm.enabled = true;
    }
  }

  function getResult() {
    let ret = [];
    result.forEach(t => {
      let t2 = [];
      t.forEach(v => t2.push(v.cid));
      ret.push(t2);
    });
    return ret;
  }
}
