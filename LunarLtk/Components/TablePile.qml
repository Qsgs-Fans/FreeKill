// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import LunarLtk
import LunarLtk.Models
import LunarLtk.Components

Item {
  id: root

  required property RoomModel roomModel
  property var discardedCards: [] // 即将消失的牌
  property var cardMap: new Map() // 用于存储被移除的牌的原件索引，避免触发一些不必要的事件
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

  function inTable(card) {
    return Lua.client.processing_area.includes(card.dataModel?.cardId);
  }

  function updateCardMap(removed) {
    const v = cardMap.get(removed);
    if (!v) return;
    cardMap.delete(removed);
    v[0].dataModel = v[1];
  }

  Timer {
    id: vanishTimer
    interval: 1500
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      let i, card;
      if (root.toVanish) {
        for (i = 0; i < root.discardedCards.length; i++) {
          card = root.discardedCards[i];
          if (card.busy || root.inTable(card)) {
            root.updateCardMap(root.discardedCards.splice(i, 1)[0]);
            i--;
            continue;
          }
          card.origOpacity = 0;
          card.destroyOnStop();
          card.goBack(true);
        }

        root.cards = root.cards.filter((c) => !root.discardedCards.find(d => root.cardMap.get(d.dataModel)[0] === c));
        area.length = root.cards.length;
        root.updateCardPosition(true);

        root.roomModel.vanishDiscard(root.discardedCards.map(e => root.cardMap.get(e.dataModel)[0]));
        for (i = 0; i < root.discardedCards.length; i++) {
          root.updateCardMap(root.discardedCards[i]);
        }
        root.discardedCards = [];
        const model_component = Qt.createComponent("LunarLtk.Models", "CardModel");
        for (i = 0; i < root.cards.length; i++) {
          const orig_card = root.cards[i];
          if (orig_card.busy || root.inTable(orig_card))
            continue;
          const orig_data = orig_card.dataModel;
          let model = model_component.createObject(null, {
            cardId: orig_data.cardId,
            virtId: orig_data.virtId,
            name: orig_data.name,
            virtName: orig_data.virtName,
            number: orig_data.number,
            suit: orig_data.suit,
            color: orig_data.color,
            picName: orig_data.pic_name,
            extension: orig_data.extension,
            type: orig_data.type,
            subtype: orig_data.subtype,
            known: orig_data.known,
            marks: orig_data.marks,
            footnote: orig_data.footnote,
          });
          root.cardMap.set(model, [orig_card, orig_data]);
          orig_card.dataModel = model;
          root.discardedCards.push(orig_card);
        }
        root.toVanish = false;
      } else {
        let model;
        for (i = 0; i < root.discardedCards.length; i++) {
          if (!root.inTable(root.discardedCards[i])) {
            // 对不在场的卡牌进行视觉处理
            card = root.discardedCards[i];
            model = card.dataModel
            model.selectable = false;
            card.z -= 255;
          }
        }
        root.toVanish = true;
      }
    }
  }

  function add(inputs) {
    area.add(inputs);
    for (const c of inputs) {
      c.dataModel.footnoteVisible = true;
      c.markVisible = false;
      c.dataModel.selectable = true;
      c.cardScale = 0.8;
      if (Config.rotateTableCard) {
        c.rotation = (Math.random() - 0.5) * 5;
      }
    }
  }

  function remove(models) {
    let i, j;

    const to_remove = root.cards.filter(cd =>
      models.find(e => e.cardId === cd.dataModel.cardId && cd.dataModel.known === e.known
        && !root.discardedCards.find(e => root.cardMap.get(e.dataModel)[0] === cd))
    ).map(c => c.dataModel);
    let result = area.remove(to_remove);
    result.forEach(c => {
      /* const idx = root.discardedCards.findIndex(e => root.cardMap.get(e.dataModel)[0] === c);
      if (idx !== -1) {
        root.updateCardMap(root.discardedCards.splice(idx, 1)[0]);
      } */
      c.dataModel.footnoteVisible = false;
      c.dataModel.selectable = false;
      c.cardScale = 1;
      c.rotation = 0;
    });

    const vanished = models.filter(e => {
      return !result.find(cd => cd.dataModel.cardId === e.cardId);
    });
    result = result.concat(invisibleArea.remove(vanished));

    updateCardPosition(true);
    return result;
  }

  function updateCardPosition(animated) {
    area.updateCardPosition(animated);
  }
}
