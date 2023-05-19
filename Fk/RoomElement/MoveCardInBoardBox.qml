// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk.Pages

GraphicsBox {
  id: root
  property var cards: []
  property var result
  property var cardsPosition: []
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
      model: 2

      Row {
        spacing: 5

        Repeater {
          id: cardRepeater
          model: cards

          Rectangle {
            color: "#1D1E19"
            width: 93
            height: 130

            Text {
              anchors.centerIn: parent
              text: Backend.translate(JSON.parse(Backend.callLuaFunction("GetCardData", [modelData.cid])).subtype)
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

      selectable: !result || result === this
      onClicked: {
        if (!selectable) return;
        if (result === this) {
          result = undefined;
        } else {
          result = this;
        }

        updatePosition(this);
      }
    }
  }

  function arrangeCards() {
    for (let i = 0; i < cards.length; i++) {
      const curCard = cardItem.itemAt(i);
      curCard.origX = i * 98;
      curCard.origY = cardsPosition[i] * 300;
      curCard.goBack(true);
    }
  }

  function updatePosition(item) {
    for (let i = 0; i < 2; i++) {
      const index = cards.findIndex(data => item.cid === data.cid);
      const cardPos = cardsPosition[index] === 0 ? (result ? 1 : 0) : (result ? 0 : 1);
      const curArea = areaRepeater.itemAt(cardPos);
      const curBox = curArea.cardRepeater.itemAt(index);
      const curPos = mapFromItem(curArea, curBox.x, curBox.y);

      item.origX = curPos.x;
      item.origY = curPos.y;
      item.goBack(true);

      buttonConfirm.enabled = !!result;
    }
  }

  function getResult() {
    return result.cid;
  }
}
