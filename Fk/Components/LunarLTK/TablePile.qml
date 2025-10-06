// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk

Item {
  id: root

  property var discardedCards: [] // 即将消失的牌
  property alias cards: area.cards
  property bool toVanish: false

  CardArea {
    id: area
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(root.width, length * 93 * 0.8 + 1)
  }

  InvisibleCardArea {
    id: invisibleArea
    anchors.horizontalCenter: parent.horizontalCenter
  }

  // FIXME: 重构需要
  function inTable(cid) {
    return Lua.evaluate(`(function()
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
          if (card.busy || inTable(card.cid) || card.holding_event_id !== 0) {
            discardedCards.splice(i, 1);
            continue;
          }
          card.origOpacity = 0;
          card.destroyOnStop();
          card.goBack(true);
        }

        cards = cards.filter((c) => discardedCards.indexOf(c) === -1);
        area.length = cards.length;
        updateCardPosition(true);

        discardedCards = [];
        for (i = 0; i < cards.length; i++) {
          if (cards[i].busy || inTable(cards[i].cid) || cards[i].holding_event_id !== 0)
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

  function add(inputs) {
    area.add(inputs);
    // if (!inputs instanceof Array)
    for (const c of inputs) {
      c.footnoteVisible = true;
      c.markVisible = false;
      c.selectable = true;
      // c.height = c.height * 0.8;
      // c.width = c.width * 0.8;
      c.cardScale = 0.8;
      if (Config.rotateTableCard) {
        c.rotation = (Math.random() - 0.5) * 5;
      }
    }
  }

  function remove(ids, _, visibleData) {
    visibleData = visibleData ?? {};
    let i, j;

    const to_remove = cards.filter(cd => {
      return ids.includes(cd.cid) &&
        cd.known === !!visibleData[cd.cid.toString()];
    }).map(c => c.cid);
    let result = area.remove(to_remove);
    result.forEach(c => {
      const idx = discardedCards.indexOf(c);
      if (idx !== -1) {
        discardedCards.splice(idx, 1);
      }
      c.footnoteVisible = false;
      c.selectable = false;
      // c.height = c.height / 0.8;
      // c.width = c.width / 0.8;
      c.cardScale = 1;
      c.rotation = 0;
    });

    const vanished = ids.filter(id => {
      return !result.find(cd => cd.cid === id);
    });
    result = result.concat(invisibleArea.remove(vanished));

    updateCardPosition(true);
    return result;
  }

  function updateCardPosition(animated) {
    area.updateCardPosition(animated);
  }
}
