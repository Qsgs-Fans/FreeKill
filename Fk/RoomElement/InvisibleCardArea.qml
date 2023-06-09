// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

Item {
  property var cards: []
  property int length: 0
  property var pendingInput: []
  property bool checkExisting: false

  id: root

  function add(inputs)
  {
    let card;
    if (inputs instanceof Array) {
      for (let i = 0; i < inputs.length; i++) {
        card = inputs[i];
        pendingInput.push(card);
        cards.push(card.toData());
      }

      if (checkExisting)
        length = cards.length;
      else
        length += inputs.length;
    } else {
      pendingInput.push(inputs);
      cards.push(inputs.toData());

      if (checkExisting)
        length = cards.length;
      else
        length++;
    }
  }

  function _contains(cid)
  {
    if (!checkExisting)
      return true;

    for (let i = 0; i < cards.length; i++)
    {
      if (cards[i].cid === cid)
        return true;
    }
    return false;
  }

  function remove(outputs)
  {
    const component = Qt.createComponent("CardItem.qml");
    if (component.status !== Component.Ready)
      return [];

    const parentPos = roomScene.mapFromItem(root, 0, 0);
    let card;
    const items = [];
    for (let i = 0; i < outputs.length; i++) {
      if (_contains(outputs[i])) {
        const state = JSON.parse(Backend.callLuaFunction("GetCardData", [outputs[i]]))
        state.x = parentPos.x;
        state.y = parentPos.y;
        state.opacity = 0;
        card = component.createObject(roomScene.dynamicCardArea, state);
        card.x -= card.width / 2;
        card.x += (i - outputs.length / 2) * 15;
        card.y -= card.height / 2;
        items.push(card);
        if (checkExisting) {
          for (let j = 0; j < length; j++) {
            if (cards[j].cid == card.cid) {
              cards.splice(j, 1);
              break;
            }
          }
        }
      }
    }
    if (checkExisting)
      length = cards.length;
    else
      length -= outputs.length;
    return items;
  }

  function updateCardPosition(animated)
  {
    let i, card;

    if (animated) {
      const parentPos = roomScene.mapFromItem(root, 0, 0);
      for (i = 0; i < pendingInput.length; i++) {
        card = pendingInput[i];
        card.origX = parentPos.x - card.width / 2 + ((i - pendingInput.length / 2) * 15);
        card.origY = parentPos.y - card.height / 2;
        card.origOpacity = 0;
        card.destroyOnStop();
      }

      for (i = 0; i < pendingInput.length; i++)
        pendingInput[i].goBack(true);
    } else {
      for (i = 0; i < pendingInput.length; i++) {
        card = pendingInput[i];
        card.x = parentPos.x - card.width / 2;
        card.y = parentPos.y - card.height / 2;
        card.opacity = 1;
        card.destroy();
      }
    }

    pendingInput = [];
  }
}
