// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk

Item {
  property alias cards: cardArea.cards
  property alias length: cardArea.length
  property var selectedCards: []

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
    card.showDetail = true;
    card.clicked.connect(adjustCards);
  }

  function remove(outputs)
  {
    const result = cardArea.remove(outputs);
    let card;
    for (let i = 0; i < result.length; i++) {
      card = result[i];
      card.draggable = false;
      card.selectable = false;
      card.showDetail = false;
      card.selectedChanged.disconnect(adjustCards);
    }
    return result;
  }

  function enableCards(cardIds)
  {
    let card, i;
    cards.forEach(card => {
      card.selectable = cardIds.contains(card.cid);
      if (!card.selectable) {
        card.selected = false;
        unselectCard(card);
      }
    });
    updateCardPosition(true);
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

  function adjustCards()
  {
    area.updateCardPosition(true);

    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      if (card.selected) {
        if (!selectedCards.contains(card))
          selectCard(card);
      } else {
        if (selectedCards.contains(card))
          unselectCard(card);
      }
    }
  }

  function selectCard(card)
  {
    selectedCards.push(card);
    cardSelected(card.cid, true);
  }

  function unselectCard(card)
  {
    for (let i = 0; i < selectedCards.length; i++) {
      if (selectedCards[i] === card) {
        selectedCards.splice(i, 1);
        cardSelected(card.cid, false);
        break;
      }
    }
  }

  function unselectAll(exceptId) {
    let card = undefined;
    for (let i = 0; i < selectedCards.length; i++) {
      if (selectedCards[i].cid !== exceptId) {
        selectedCards[i].selected = false;
      } else {
        card = selectedCards[i];
        card.selected = true;
      }
    }
    if (card === undefined) {
      selectedCards = [];
    } else {
      selectedCards = [card];
    }
    updateCardPosition(true);
  }
}
