// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

// CardArea stores CardItem.

Item {
  property var cards: []
  property int length: 0

  id: root

  function add(inputs)
  {
    if (inputs instanceof Array) {
      cards.push(...inputs);
    } else {
      cards.push(inputs);
    }
    length = cards.length;
  }

  function remove(outputs)
  {
    let result = [];
    for (let j = 0; j < outputs.length; j++) {
      for (let i = cards.length - 1; i >= 0; i--) {
        if (outputs[j] === cards[i].cid) {
          const state = JSON.parse(Backend.callLuaFunction("GetCardData", [cards[i].cid]));
          cards[i].setData(state);
          result.push(cards[i]);
          cards.splice(i, 1);
          i--;
          break;
        }
      }
    }
    length = cards.length;
    return result;
  }

  function updateCardPosition(animated)
  {
    let i, card;

    let overflow = false;
    for (i = 0; i < cards.length; i++) {
      card = cards[i];
      card.origX = i * card.width;
      if (card.origX + card.width >= root.width) {
        overflow = true;
        break;
      }
      card.origY = 0;
    }

    if (overflow) {
      // TODO: Adjust cards in multiple lines if there are too many cards
      const xLimit = root.width - card.width;
      const spacing = xLimit / (cards.length - 1);
      for (i = 0; i < cards.length; i++) {
        card = cards[i];
        card.origX = i * spacing;
        card.origY = 0;
        card.z = i + 1;
        card.initialZ = i + 1;
        card.maxZ = cards.length;
      }
    }

    const parentPos = roomScene.mapFromItem(root, 0, 0);
    for (i = 0; i < cards.length; i++) {
      card = cards[i];
      card.origX += parentPos.x;
      card.origY += parentPos.y;
    }

    if (animated) {
      for (i = 0; i < cards.length; i++)
        cards[i].goBack(true);
    }
  }
}
