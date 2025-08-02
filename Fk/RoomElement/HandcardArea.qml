// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk

Item {
  property alias cards: cardArea.cards
  property alias length: cardArea.length
  property bool sortable: true
  property var selectedCards: []
  property var movepos

  signal cardSelected(int cardId, bool selected)
  signal cardDoubleClicked(int cardId, bool selected)

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
    card.markVisible = true;
    card.autoBack = true;
    // 只有会被频繁刷新的手牌才能拖动
    // card.draggable = lcall("CanSortHandcards", Self.id);
    card.selectable = false;
    card.clicked.connect(selectCard);
    card.clicked.connect(adjustCards);
    card.doubleClicked.connect(doubleClickCard);
    card.released.connect(updateCardReleased);
    card.xChanged.connect(updateCardDragging);
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
      card.selectedChanged.disconnect(adjustCards);
      card.doubleClicked.disconnect(doubleClickCard);
      card.released.disconnect(updateCardReleased);
      card.xChanged.disconnect(updateCardDragging);
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

  function updateCardDragging()
  {
    let _card, c;
    let index;
    for (index = 0; index < cards.length; index++) {
      c = cards[index];
      if (c.dragging) {
        _card = c;
        break;
      }
    }
    if (!_card) return;
    _card.goBackAnim.stop();
    _card.opacity = 0.8

    let card;
    movepos = null;
    for (let i = 0; i < cards.length; i++) {
      card = cards[i];
      if (card.dragging) continue;

      if (card.x > _card.x) {
        movepos = i - (index < i ? 1 : 0);
        break;
      }
    }
    if (movepos == null) { // 最右
      movepos = cards.length;
    }
  }

  function updateCardReleased(_card)
  {
    let i;
    if (movepos != null && sortable) {
      const handcardnum = lcall("GetPlayerHandcards", Self.id).length; // 不计入expand_pile
      if (movepos >= handcardnum) movepos = handcardnum - 1;
      i = cards.indexOf(_card);
      cards.splice(i, 1);
      cards.splice(movepos, 0, _card);
      movepos = null;
    }
    updateCardPosition(true);
  }

  function adjustCards()
  {
    area.updateCardPosition(true);
  }

  function selectCard(card) {
    if (card.selectable) cardSelected(card.cid, card.selected);
    adjustCards();
  }

  function doubleClickCard(card) {
    if (config.doubleClickUse) {
      cardDoubleClicked(card.cid, card.selected);
    }
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
    area.sortable = lcall("CanSortHandcards", Self.id);
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
    });
    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      if (!card.selectable) {
        const reason = lcall("GetCardProhibitReason", card.cid);
        card.prohibitReason = reason;
      }
    }
  }
}
