// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import Fk.Pages
import Fk.RoomElement

GraphicsBox {
  id: root
  property string prompt
  property var cards: []
  property var org_cards: []
  property var result: []
  property var areaCapacities: []
  property var areaLimits: []
  property var areaNames: []
  property var dragging_card: ""
  property var movepos: []
  property bool free_arrange: true
  property bool cancelable: false
  property string poxi_type: ""
  property string pattern: "."
  property int size: 0
  property int padding: 25

  title.text: Backend.translate(prompt !== "" ? Util.processPrompt(prompt) : "Please arrange cards")
  width: body.width + padding * 2
  height: title.height + body.height + padding * 2

  ColumnLayout {
    id: body
    x: padding
    y: parent.height - padding - height
    spacing: 10

    Repeater {
      id: areaRepeater
      model: areaCapacities

      Row {
        spacing: 7

        property int areaCapacity: modelData
        property string areaName: index < areaNames.length ? qsTr(Backend.translate(areaNames[index])) : ""

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
            text: areaName
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
          model: (size === 0) ? areaCapacity : 1

          Rectangle {
            color: "#1D1E19"
            width: (size === 0) ? 93 : size * 100 - 7
            height: 130

          }
        }
        property alias cardRepeater: cardRepeater
      }
    }

    Row {
      Layout.alignment: Qt.AlignHCenter
      spacing: 32

      MetroButton {
        width: 120
        height: 35
        id: buttonConfirm
        text: luatr("OK")
        onClicked: {
          close();
          roomScene.state = "notactive";
          const reply = getResult();
          ClientInstance.replyToServer("", reply);
        }
      }

      MetroButton {
        width: 120
        height: 35
        text: luatr("Cancel")
        visible: root.cancelable
        onClicked: {
          close();
          roomScene.state = "notactive";
          const ret = [];
          let i;
          for (i = 0; i < result.length; i++) {
            ret.push([]);
          }
          const reply = ret;
          ClientInstance.replyToServer("", reply);
        }
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
      onReleased: updateCardReleased(this);
      onDraggingChanged: {
        if (!dragging) return;
        dragging_card = this;
        let i, card
        for (i = 0; i < cardItem.count; i++) {
          card = cardItem.itemAt(i);
          if (card !== this)
            card.draggable = false;
        }
      }
      onXChanged : updateCardDragging(this);
      onYChanged : updateCardDragging(this);
      onSelectedChanged : updateCardSelected(this);
    }
  }

  function updateCardDragging(_card) {
    if (!_card.dragging) return;
    _card.goBackAnim.stop();
    _card.opacity = 0.5
    let i, j
    let box, pos, pile;
    movepos = [];
    for (j = 0; j <= result.length; j++) {
      if (j >= result.length) {
        arrangeCards();
        return;
      }
      pile = areaRepeater.itemAt(j);
      if (pile.y === 0) {
        pile.y = j * 140
      }
      box = pile.cardRepeater.itemAt(0);
      pos = mapFromItem(pile, box.x, box.y);
      if (Math.abs(pos.y - _card.y) < 130 / 2) break;
    }
    if (result[j].includes(_card)) {
      if (j === 0 && !free_arrange) {
        arrangeCards();
        return;
      }
    } else if (!_card.selectable) {
      arrangeCards();
      return;
    }

    let card;
    let index = result[j].indexOf(_card);
    if (index === -1 && result[j].length === areaCapacities[j]) {
      for (i = result[j].length; i > 0; i--) {
        card = result[j][i-1];
        if (card === _card) continue;
        if (Math.abs(card.x - _card.x) <= card.width / 2 && card.selectable) {
          movepos = [j, i-1];
          break;
        }
      }
    } else {
      for (i = 0; i < result[j].length; i++) {
        card = result[j][i];
        if (card.dragging) continue;

        if (card.x > _card.x) {
          movepos = [j, i - ((index !==-1 && index < i) ? 1 : 0)];
          break;
        }
      }
      if (movepos.length === 0)
        movepos = [j, result[j].length - ((index === -1) ? 0 : 1)];

      if (!free_arrange && j === 0 && org_cards[0].includes(_card.cid)) {
        let a = 0, b = -1, c = -1;
        i = 0;
        while (i < result[j].length && a < org_cards[0].length) {
          if (result[j][i].cid === org_cards[0][a]) {
            if (b !==c) {
              c = i;
              break;
            }
            i++;
            a++;
          } else {
            if (b === -1)
              b = i;
            if (org_cards[0].includes(result[j][i].cid)) {
              a++;
            } else {
              i++;
            }
          }
        }
        if (b === -1) b = result[j].length;
        if (c === -1) c = result[j].length;

        if (b === c)
          movepos = [j, b];
        else if (movepos[1] < b || (movepos[1] > c && c !==-1))
          movepos = [];
      }
    }
    arrangeCards();
  }

  function updateCardReleased(_card) {
    let i, j;
    if (movepos.length === 2) {
      for (j = 0; j < result.length; j++) {
        i = result[j].indexOf(_card);
        if (i !==-1) {
          if (j !==movepos[0] && result[movepos[0]].length === areaCapacities[movepos[0]]) {
            result[j][i] = result[movepos[0]][movepos[1]];
            result[movepos[0]][movepos[1]] = _card;
            if (!free_arrange && result[0].length < areaCapacities[0])
              result[0].sort((a, b) => org_cards[0].indexOf(a.cid) - org_cards[0].indexOf(b.cid));
          } else {
            result[j].splice(i, 1);
            result[movepos[0]].splice(movepos[1], 0, _card);
          }
          movepos = [];
          break;
        }
      }
    }
    dragging_card = "";
    arrangeCards();
  }

  function updateCardSelected(_card) {
    let i = result[0].indexOf(_card);
    let j;
    if (i === -1) {
      if (result[0].length < areaCapacities[0]) {
        if (free_arrange || !org_cards[0].includes(_card.cid)) {
          for (j = 1; j < result.length; j++) {
            i = result[j].indexOf(_card);
            if (i !==-1) {
              result[j].splice(i, 1);
              result[0].push(_card);
              arrangeCards();
              break;
            }
          }
        } else {
          i = 0;
          j = 0;
          while (i < result[0].length && j < org_cards[0].length) {
            if (org_cards[0][j] === _card.cid) break;
            if (result[0][i].cid === org_cards[0][j]) {
              i++;
              j++;
            } else {
              if (org_cards[0].includes(result[0][i].cid))
                j++;
              else
                i++;
            }
          }
          let index;
          for (j = 1; j < result.length; j++) {
            index = result[j].indexOf(_card);
            if (index !== -1) {
              result[j].splice(index, 1);
              result[0].splice(i, 0, _card);
              arrangeCards();
              break;
            }
          }
        }
      }
    } else {
      for (j = 1; j < result.length; j++) {
        if (result[j].length < areaCapacities[j]) {
          result[0].splice(i, 1);
          result[j].push(_card);
          arrangeCards();
          break;
        }
      }
    }
  }

  function arrangeCards() {
    let i, j, a, b;
    let card, box, pos, pile;
    let spacing;
    let same_row;
    let c_result = getResult();
    let is_exchange = (movepos.length === 2 && !result[movepos[0]].includes(dragging_card) && result[movepos[0]].length === areaCapacities[movepos[0]])
    for (j = 0; j < result.length; j++) {
      pile = areaRepeater.itemAt(j);
      box = pile.cardRepeater.itemAt(0);
      if (pile.y === 0) {
        pile.y = j * 140
      }
      a = result[j].length;
      if (movepos.length === 2) {
        if (movepos[0] === j && !result[j].includes(dragging_card) && result[j].length < areaCapacities[j]) {
          a++;
        } else if (movepos[0] !== j && result[j].includes(dragging_card)) {
          a--;
        }
      }
      spacing = (size > 0 && a > size) ? ((size - 1) * 100 / (a - 1)) : 100;
      b = 0;
      for (i = 0; i < result[j].length; i++) {
        card = result[j][i];
        if (card.dragging) {
          if (movepos.length !== 2 || movepos[0] !== j)
            b++;
          continue;
        }
        if (movepos.length === 2 && movepos[0] === j && b === movepos[1] && !is_exchange)
          b++;
        pos = mapFromItem(pile, box.x, box.y);
        card.glow.visible = false;
        card.chosenInBox = (movepos.length === 2 && result[j].length === areaCapacities[j] && movepos[0] === j && movepos[1] === b);
        card.origX = (movepos.length === 2 && movepos[0] === j && b > (movepos[1] - (is_exchange ? 0 : 1))) ? (pos.x + (b - 1) * spacing + 100) : (pos.x + b * spacing);
        card.origY = pos.y;
        card.opacity = 1;
        card.z = i + 1;
        card.initialZ = i + 1;
        card.maxZ = cardItem.count;

        if (poxi_type !== "")
          card.selectable = lcall("PoxiFilter", poxi_type, card.cid, [dragging_card.cid], c_result, org_cards);
        else if (pattern !== ".")
          card.selectable = lcall("CardFitPattern", card.cid, pattern);
        else {
          if (free_arrange || dragging_card === "")
            card.selectable = true;
          else if (result[j].length < areaCapacities[j] + (result[j].includes(dragging_card) ? 1 : 0))
            card.selectable = (j !== 0);
          else {
            if (j === 0)
              card.selectable = !org_cards[0].includes(dragging_card.cid) || i === org_cards[0].indexOf(dragging_card.cid);
            else {
              if (result[0].includes(dragging_card))
                card.selectable = result[0].length < areaCapacities[0] || !org_cards[0].includes(card.cid) || card.cid === org_cards[0][result[0].indexOf(dragging_card)]
              else
                card.selectable = org_cards[0].includes(dragging_card.cid) || card.cid === org_cards[0][result[0].indexOf(dragging_card)]
            }
          }
        }
        card.draggable = (dragging_card === "") && (free_arrange || j > 0 || card.selectable);
        card.goBack(true);
        b++;
      }
    }

    for (i = 0; i < areaRepeater.count; i++) {
      if (result[i].length < areaLimits[i]) {
        buttonConfirm.enabled = false;
        break;
      }
      buttonConfirm.enabled = poxi_type ? lcall("PoxiFeasible", poxi_type, [], c_result, org_cards) : true;
    }
  }

  function initializeCards() {
    result = new Array(areaCapacities.length);
    let i, j;
    let k = 0;
    for (i = 0; i < result.length; i++){
      result[i] = [];
    }

    let card;

    for (j = 0; j < org_cards.length; j++){
      for (i = 0; i < org_cards[j].length; i++){
        result[j].push(cardItem.itemAt(k));
        k++;
      }
    }

    arrangeCards();
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
}
