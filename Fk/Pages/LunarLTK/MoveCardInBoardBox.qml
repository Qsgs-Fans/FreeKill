// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import Fk.Components.LunarLTK

GraphicsBox {
  id: root
  property var cards: []
  property var cardsPosition: []
  property var generalNames: []
  property var playerIds: []
  property var result
  property int padding: 25

  title.text: Lua.tr("Please click to move card")
  width: body.width + padding * 2
  height: title.height + body.height + padding * 2

  ColumnLayout {
    id: body
    x: padding
    y: parent.height - padding - height
    spacing: 20

    Repeater {
      id: areaRepeater
      model: generalNames

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
            text: modelData
            color: "white"
            font.family: Config.libianName
            font.pixelSize: 18
            style: Text.Outline
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
          }
        }

        Repeater {
          id: cardRepeater
          model: cards

          Rectangle {
            color: "#4A4139"
            width: 93
            height: 130
            opacity: 0.5

            Text {
              horizontalAlignment: Text.AlignHCenter
              anchors.centerIn: parent
              text: Lua.tr(modelData.subtype)
              color: "#90765F"
              font.family: Config.libianName
              font.pixelSize: 16
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
      text: Lua.tr("OK")
      width: 120
      height: 35
      enabled: false

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
      virt_name: modelData.virt_name || ''
      known: Lua.call("CardVisibility", modelData.cid)

      selectable: !result || result.item === this
      onClicked: {
        if (!selectable) return;
        if ((result || {}).item === this) {
          result = undefined;
        } else {
          result = { item: this };
        }

        updatePosition(this);
      }
    }
  }

  function arrangeCards() {
    for (let i = 0; i < cards.length; i++) {
      const curCard = cardItem.itemAt(i);
      curCard.origX = i * 98 + 50;
      curCard.origY = cardsPosition[i] * 150 + body.y;
      curCard.goBack();
    }
  }

  function updatePosition(item) {
    for (let i = 0; i < 2; i++) {
      const index = cards.findIndex(data => item.cid === data.cid);
      result && (result.pos = cardsPosition[index]);

      const cardPos = cardsPosition[index] === 0 ? (result ? 1 : 0)
                                                 : (result ? 0 : 1);
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
    return result ? { cardId: result.item.cid, pos: result.pos } : '';
  }
}
