// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import Fk.Pages

GraphicsBox {
  id: root
  property string yuqi_type
  property var cards: [] //全体卡牌枚举
  property var result: [] //最终牌堆
  property var pilecards: [] //初始牌堆
  property var areaNames: [] //牌堆名
  property bool cancelable: true
  property var extra_data
  property int padding: 25

  signal cardsSelected(var ids)

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
        property alias cardsArea: cardsArea
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
        enabled: lcall("YuqiFeasible", root.yuqi_type, root.getResult(),
                      root.pilecards, root.extra_data);
        onClicked: root.cardsSelected(root.getResult())
      }

      MetroButton {
        width: 120
        height: 35
        text: luatr("Cancel")
        visible: root.cancelable
        onClicked: root.cardsSelected([])
      }

    }
  }

  Repeater {
    id: cardsItem
    model: cards

    CardItem {
      x: index
      y: -1
      cid: modelData.cid
      name: modelData.name
      suit: modelData.suit
      number: modelData.number
      draggable: true
      onReleased: updateCardsReleased(this);
    }
  }

  function updateCardsReleased(card) {
    let orig, from, to;
    let i, j;
    const result_cards = getResult();
    for (i = 0; i < pilecards.count; i++) {
      const _pile = result[i];
      const box = pile.cardsArea;
      const pos = mapFromItem(pile, box.x, box.y);
      const posid = _pile.indexOf(card.cid)
      if (posid !== -1) {
        from = i;
        orig = posid;
      }
      const spacing = (_pile.length > 8) ? (700 / (_pile.length - 1)) : 100
      if (Math.abs(card.y - pos.y) <= spacing / 2) {
        to = i
      }
      if (from !== null && to !== null) {
        if (pilecards[to].indexOf(card.cid) === -1 && !lcall("YuqiEntryFilter", root.yuqi_type, card.cid, from, to,
                      result_cards, root.extra_data) ) break;
        result[from].splice(orig, 1)
        for (j = 0; j < result[0].length; j++) {
          let _card = result[orig][i]
          if (Math.abs(card.x - _card.x) <= card.width / 2) {
            result[to].splice(j, 0, card.cid);
            break;
          }
        }
        break;
      }
    }
    arrangeCards();
  }

  function arrangeCards() {
    let i, j;
    let card, box, pos, pile;
    let spacing;
    const result_cards = getResult();
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
        card.draggable = lcall("YuqiOutFilter", root.yuqi_type, card.cid, j,
                      result_cards, root.extra_data);
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

  function getResult() {
    const ret = [];
    result.forEach(t => {
      const t2 = [];
      t.forEach(v => t2.push(v.cid));
      ret.push(t2);
    });
    return ret;
  }

  function refreshPrompt() {
    root.title.text = Util.processPrompt(lcall("YuqiPrompt", yuqi_type, root.result, root.pilecards, extra_data))
  }
}
