// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk

Item {
  property alias cards: cardArea.cards
  property alias length: cardArea.length

  signal cardSelected(int cardId, bool selected)

  id: area

  CardArea {
    anchors.fill: parent
    id: cardArea
    onLengthChanged: area.updateCardPosition(true);
  }

  function add(inputs)
  {
    cardArea.add(inputs);
    if (inputs instanceof Array) {
      for (let i = 0; i < inputs.length; i++)
        filterInputCard(inputs[i]);
    } else {
      filterInputCard(inputs);
    }
  }

  function filterInputCard(card)
  {
    card.autoBack = true;
    card.draggable = true;
    card.selectable = false;
    card.clicked.connect(selectCard);
  }

  function remove(outputs)
  {
    const result = cardArea.remove(outputs);
    let card;
    for (let i = 0; i < result.length; i++) {
      card = result[i];
      card.draggable = false;
      card.selectable = false;
      card.clicked.disconnect(selectCard);
      card.prohibitReason = "";
    }
    return result;
  }

  function updateCardPosition(animated)
  {
    cardArea.updateCardPosition(false);

    cards.forEach(card => {
      if (card.selected) {
        card.origY -= 20;
      }
      if (!card.selectable) {
        if (config.hideUseless) {
          card.origY += 60;
        }
      }
    });

    if (animated) {
      cards.forEach(card => card.goBack(true));
    }
  }

  function adjustCards() {
    area.updateCardPosition(true);
  }

  function selectCard(card) {
    cardSelected(card.cid, card.selected);
    adjustCards();
  }

  function enableCards(cardIds)
  {
    let card, i;
    cards.forEach(card => {
      card.selectable = cardIds.includes(card.cid);
      if (!card.selectable) {
        card.selected = false;
      }
    });
    updateCardPosition(true);
  }

  function unselectAll() {
    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      card.selected = false;
    }
    updateCardPosition(true);
  }

  function applyChange(uiUpdate) {
    uiUpdate["CardItem"]?.forEach(cdata => {
      for (let i = 0; i < cards.length; i++) {
        const card = cards[i];
        if (card.cid === cdata.id) {
          card.selectable = cdata.enabled;
          card.selected = cdata.selected;
          updateCardPosition(true);
          break;
        }
      }
    })
  }
}
