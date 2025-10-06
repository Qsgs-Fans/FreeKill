// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk

Item {
  id: area

  property alias cards: cardArea.cards
  property alias length: cardArea.length
  property bool sortable: true
  property var selectedCards: []
  property var movepos

  property var draggingCard
  property var draggingClickedPhoto

  signal cardSelected(int cardId, bool selected)
  signal cardDoubleClicked(int cardId, bool selected)

  CardArea {
    id: cardArea
    anchors.fill: parent
    onLengthChanged: area.updateCardPosition(true);
  }

  function add(inputs) {
    cardArea.add(inputs);
    if (inputs instanceof Array) {
      for (let i = 0; i < inputs.length; i++)
        filterInputCard(inputs[i]);
    } else {
      filterInputCard(inputs);
    }
  }

  function filterInputCard(card) {
    card.markVisible = true;
    card.autoBack = true;
    // 只有会被频繁刷新的手牌才能拖动
    // card.draggable = Lua.call("CanSortHandcards", Self.id);
    card.selectable = false;
    card.clicked.connect(selectCard);
    card.clicked.connect(adjustCards);
    card.doubleClicked.connect(doubleClickCard);
    card.released.connect(updateCardReleased);
    card.startDrag.connect(updateCardDragging);
  }

  function remove(outputs) {
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
      card.startDrag.disconnect(updateCardDragging);
      card.prohibitReason = "";
    }
    return result;
  }

  function updateCardPosition(animated) {
    cardArea.updateCardPosition(false);

    cards.forEach(card => {
      if (card.selected) {
        card.origY -= 20;
      }
      if (!card.selectable) {
        if (Config.hideUseless) {
          card.origY += 60;
        }
      }
    });

    if (animated) {
      cards.forEach(card => {
        if (!card.dragging) card.goBack(true);
      });
    }
  }

  function updateCardDragging(_card) {
    if (!_card) return;
    _card.goBackAnim.stop();
    _card.opacity = 0.8

    if (Config.enableSuperDrag) {
      draggingCard = _card;
      draggingClickedPhoto = null;
      _card.xChanged.connect(dragMovement);
      _card.yChanged.connect(dragMovement);
    }
  }

  function dragMovement() {
    if (!Config.enableSuperDrag) return;
    const card = draggingCard;
    if (!card) return;
    const x = card.x + card.dragCenter.x;
    const y = card.y + card.dragCenter.y;
    if (y >= roomScene.dashboard.y && x <= roomScene.getPhoto(Self.id).x) {
      return;
    }
    if (!card.selectable) return;

    if (!card.selected) {
      cardSelected(card.cid, true);
    }

    const pids = Lua.evaluate('table.map(ClientInstance.players, Util.IdMapper)');
    let belowPhoto;
    for (const pid of pids) {
      const photo = roomScene.getPhoto(pid);
      const actualW = photo.width * photo.scale;
      const actualH = photo.height * photo.scale;
      const actualX = photo.x + (photo.width - actualW) / 2;
      const actualY = photo.y + (photo.height - actualH) / 2;

      if (x >= actualX && x <= actualX + actualW && y >= actualY && y <= actualY + actualH) {
        belowPhoto = photo;
        if (draggingClickedPhoto === photo) continue;
        draggingClickedPhoto = photo;
        photo.selected = photo.selectable ? !photo.selected : false;
      }
    }

    if (!belowPhoto) draggingClickedPhoto = null;
  }

  function updateCardReleased(_card) {
    let i;
    let c;
    let index;

    const inDragUse = (Config.enableSuperDrag && _card === draggingCard);
    draggingCard = null;
    draggingClickedPhoto = null;
    _card.xChanged.disconnect(dragMovement);
    _card.yChanged.disconnect(dragMovement);

    if (inDragUse) {
      const x = _card.x + _card.dragCenter.x;
      const y = _card.y + _card.dragCenter.y;
      if ((y < roomScene.dashboard.y || x > roomScene.getPhoto(Self.id).x) && roomScene.okButton.enabled) {
        roomScene.okButton.clicked();
        return;
      } else if (_card.selected) {
        cardSelected(_card.cid, false);
      }
    }

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

    if (sortable && movepos != null) {
      const handcardnum = Lua.call("GetPlayerHandcards", Self.id).length; // 不计入expand_pile
      const isMyHandcard = Lua.evaluate(`ClientInstance:getCardArea(${_card.cid}) == Card.PlayerHand and ClientInstance:getCardOwner(${_card.cid}) == Self`);
      if (isMyHandcard) {
        if (movepos >= handcardnum) movepos = handcardnum - 1;
      } else {
        if (movepos < handcardnum) movepos = handcardnum;
      }
      i = cards.indexOf(_card);
      cards.splice(i, 1);
      cards.splice(movepos, 0, _card);
      movepos = null;
    }
    updateCardPosition(true);
  }

  function adjustCards() {
    area.updateCardPosition(true);
  }

  function selectCard(card) {
    if (card.selectable) cardSelected(card.cid, card.selected);
    adjustCards();
  }

  function doubleClickCard(card) {
    if (Config.doubleClickUse) {
      cardDoubleClicked(card.cid, card.selected);
    }
  }

  function enableCards(cardIds) {
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
    area.sortable = Lua.call("CanSortHandcards", Self.id);
    uiUpdate["CardItem"]?.forEach(cdata => {
      for (let i = 0; i < cards.length; i++) {
        const card = cards[i];
        if (card.cid === cdata.id) {
          card.selectable = cdata.enabled;
          card.selected = cdata.selected;
          break;
        }
      }
    });
    updateCardPosition(true);
    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      if (!card.selectable) {
        const reason = Lua.call("GetCardProhibitReason", card.cid);
        card.prohibitReason = reason;
      }
    }
  }
}
