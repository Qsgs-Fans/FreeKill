// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

Item {
  property var discardedCards: []
  property alias cards: area.cards
  property bool toVanish: false

  id: root

  CardArea {
    id: area
  }

  InvisibleCardArea {
    id: invisibleArea
  }

  // FIXME: 重构需要
  function inTable(cid) {
    return leval(`(function()
      local client = Fk:currentRoom()
      if table.contains(client.processing_area, ${cid}) then
        return true
      end
      return false
    end)()`)
  }

  Timer {
    id: vanishTimer
    interval: 1500
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      let i, card;
      if (toVanish) {
        for (i = 0; i < discardedCards.length; i++) {
          card = discardedCards[i];
          if (card.busy || inTable(card.cid)) {
            discardedCards.splice(i, 1);
            continue;
          }
          card.origOpacity = 0;
          card.goBack(true);
          card.destroyOnStop()
        }

        cards = cards.filter((c) => discardedCards.indexOf(c) === -1);
        updateCardPosition(true);

        discardedCards = [];
        for (i = 0; i < cards.length; i++) {
          if (cards[i].busy || inTable(cards[i].cid))
            continue;
          discardedCards.push(cards[i]);
        }
        toVanish = false;
      } else {
        for (i = 0; i < discardedCards.length; i++) {
          if (!inTable((discardedCards[i].cid)))
            discardedCards[i].selectable = false;
        }
        toVanish = true;
      }
    }
  }

  function add(inputs)
  {
    area.add(inputs);
    // if (!inputs instanceof Array)
    for (let i = 0; i < inputs.length; i++) {
      const c = inputs[i];
      c.footnoteVisible = true;
      c.markVisible = false;
      c.selectable = true;
      c.height = c.height * 0.8;
      c.width = c.width * 0.8;
      if (config.rotateTableCard) {
        c.rotation = (Math.random() - 0.5) * 5;
      }
    }
  }

  function remove(outputs)
  {
    let i, j;

    let result = area.remove(outputs);
    result.forEach(c => {
      const idx = discardedCards.indexOf(c);
      if (idx !== -1) {
        discardedCards.splice(idx, 1);
      }
      c.footnoteVisible = false;
      c.selectable = false;
      c.height = c.height / 0.8;
      c.width = c.width / 0.8;
      c.rotation = 0;
    });
    const vanished = [];
    if (result.length < outputs.length) {
      for (i = 0; i < outputs.length; i++) {
        let exists = false;
        for (j = 0; j < result.length; j++) {
          if (result[j].cid === outputs[i]) {
            exists = true;
            break;
          }
        }
        if (!exists)
          vanished.push(outputs[i]);
      }
    }
    result = result.concat(invisibleArea.remove(vanished));

    for (i = 0; i < result.length; i++) {
      for (j = 0; j < discardedCards.length; j++) {
        if (result[i].cid === discardedCards[j].cid) {
          discardedCards.splice(j, 1);
          break;
        }
      }
    }
    updateCardPosition(true);
    return result;
  }

  function updateCardPosition(animated)
  {
    if (cards.length <= 0)
      return;

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
      //@to-do: Adjust cards in multiple lines if there are too many cards
      const xLimit = root.width - card.width;
      const spacing = xLimit / (cards.length - 1);
      for (i = 0; i < cards.length; i++) {
        card = cards[i];
        card.origX = i * spacing;
        card.origY = 0;
      }
    }

    const offsetX = Math.max(0, (root.width - cards.length * card.width) / 2);
    const parentPos = roomScene.mapFromItem(root, 0, 0);
    for (i = 0; i < cards.length; i++) {
      card = cards[i];
      card.origX += parentPos.x + offsetX;
      card.origY += parentPos.y;
    }

    if (animated) {
      for (i = 0; i < cards.length; i++)
        cards[i].goBack(true)
    }
  }
}
