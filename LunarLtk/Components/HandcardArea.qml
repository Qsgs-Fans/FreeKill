// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.GameCommon
import LunarLtk
import LunarLtk.Components

Item {
  id: root

  required property DashboardModel dataModel

  property alias cards: cardArea.cards
  property alias length: cardArea.length
  property bool sortable: true
  property var selectedCards: []

  property var draggingCard
  property var draggingClickedPhoto

  readonly property bool folded: miscExpandArea.length > 0

  Connections {
    target: root.dataModel
    function onHandcardsSorted() {
      root.syncCards();
    }
  }

  CardArea {
    id: cardArea
    // anchors.fill: parent
    width: parent.folded ? Math.min(cards.length * 93, 120) : parent.width
    onWidthChanged: root.adjustCards();
    onLengthChanged: root.updateCardPosition(true);
  }

  // 用来显示其余展开牌的区域。显示时，手牌区会被折叠。
  // 需要自行构建想要传入的元素等。
  ItemArea {
    id: miscExpandArea
    anchors.left: cardArea.right
    anchors.leftMargin: 2
    anchors.right: parent.right

    scene: Ltk.roomScene
  }

  function cardSelected(cardId, selected) {
    Lua.updateRequestUI("CardItem", cardId, "click", { selected, autoTarget: Config.autoTarget } );
  }

  function addMiscExpand(inputs) {
    miscExpandArea.add(inputs);
    const myPos = roomScene.mapFromItem(miscExpandArea, 0, 0);
    for (const item of inputs) {
      item.x = myPos.x;
      item.y = myPos.y;
    }
    miscExpandArea.updatePosition(true);
  }

  function clearMiscExpand() {
    const myPos = roomScene.mapFromItem(miscExpandArea, 0, 0);
    for (const item of miscExpandArea.remove([...miscExpandArea.items])) {
      item.origY = myPos.y + 200;
      item.destroyOnStop();
      item.goBack(true);
    }
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
    card.dataModel.footnoteVisible = false;
    card.autoBack = true;
    // 只有会被频繁刷新的手牌才能拖动
    card.draggable = Ltk.canSortHandcards(Cpp.self.id);
    card.dataModel.selectable = false;
    card.clicked.connect(selectCard);
    card.clicked.connect(adjustCards);
    // card.doubleClicked.connect(doubleClickCard);
    card.released.connect(updateCardReleased);
    card.startDrag.connect(updateCardDragging);
  }

  function remove(outputs) {
    const result = cardArea.remove(outputs);
    for (const card of result) {
      card.draggable = false;
      card.dataModel.selectable = false;
      card.clicked.disconnect(selectCard);
      card.selectedChanged.disconnect(adjustCards);
      // card.doubleClicked.disconnect(doubleClickCard);
      card.released.disconnect(updateCardReleased);
      card.startDrag.disconnect(updateCardDragging);
      card.dataModel.prohibitReason = "";
      card.areaText = "";
      card.dataModel.known = Lua.selfPlayer.cardVisible(card.dataModel.cardId);
    }
    return result;
  }

  function updateCardPosition(animated) {
    cardArea.updateCardPosition(false);

    cards.forEach(card => {
      if (card.selected) {
        card.origY -= 20;
      }
      if (!card.selectable && Config.hideUseless) {
        card.origY += 60;
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
    if ((card?.dataModel?.cardId || 0) === 0) return; // 直接禁止虚拟牌拖动
    const x = card.x + card.dragCenter.x;
    const y = card.y + card.dragCenter.y;
    if (y >= roomScene.dashboard.y && x <= roomScene.getPhoto(Cpp.self.id).x) {
      return;
    }
    if (!card.selectable) return;

    if (!card.selected) {
      cardSelected(card.dataModel.cardId, true);
    }

    let belowPhoto;
    for (const player of Lua.client.players) {
      const photo = roomScene.getPhoto(player.id);
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
    let index = cards.indexOf(_card);
    const cid = _card.dataModel.cardId;

    const inDragUse = (Config.enableSuperDrag && _card === draggingCard);
    draggingCard = null;
    draggingClickedPhoto = null;
    _card.xChanged.disconnect(dragMovement);
    _card.yChanged.disconnect(dragMovement);

    if (inDragUse) {
      const x = _card.x + _card.dragCenter.x;
      const y = _card.y + _card.dragCenter.y;
      if ((y < roomScene.dashboard.y || x > roomScene.getPhoto(Cpp.self.id).x) && roomScene.okButton.enabled) {
        roomScene.okButton.clicked();
        return;
      } else if (_card.selected) {
        cardSelected(_card.dataModel.cardId, false);
      }
    }

    let card;
    let movepos = null;
    for (i = 0; i < cards.length; i++) {
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
      const self = Lua.selfPlayer;
      const room = Lua.client;
      const handcardnum = self.getCardIds("h").length; // 不计入expand_pile
      const isMyHandcard = room.getCardArea(cid) === Ltk.Card.PlayerHand &&
        Lua.ev(`ClientInstance:getCardOwner(${cid}).id == Self.id`);
      if (isMyHandcard) {
        if (movepos >= handcardnum) movepos = handcardnum - 1;
        dataModel.swapHandcard(movepos, index);
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
    updateCardPosition(true);
  }

  function selectCard(card) {
    if (card.selectable) cardSelected(card.dataModel.uniqueId, card.selected);
    adjustCards();
  }

  function doubleClickCard(card) {
    if (Config.doubleClickUse) {
      Lua.updateRequestUI("CardItem", card.dataModel.uniqueId, "doubleClick", { selected: card.selected, doubleClickUse: Config.doubleClickUse, autoTarget: Config.autoTarget } );
    }
  }

  function enableCards(cardIds) {
    let card, i;
    cards.forEach(card => {
      card.dataModel.selectable = cardIds.includes(card.dataModel.uniqueId);
      if (!card.dataModel.selectable) {
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

  function syncCards() {
    // sync expandedCards
    const visibleIds = dataModel.visible_ids ?? [];
    let allCards = [...dataModel.handcards, ...dataModel.expandedCards]
    if (visibleIds.length > 0) {
      allCards = allCards.filter(model => visibleIds.includes(model.uniqueId));
    }
    const orderedCards = [];
    const extractedCards = [];
    for (const card of cards) {
      const idx = allCards.findIndex(e => e === card.dataModel);
      if (idx !== -1) {
        orderedCards[idx] = card;
      } else {
        extractedCards.push(card.dataModel);
      }
    }

    const myPos = Ltk.roomScene.mapFromItem(root, 0, 0);
    for (const card of remove(extractedCards)) {
      cards.splice(cards.indexOf(card), 1);
      card.origX = myPos.x + width;
      card.origY = myPos.y;
      card.destroyOnStop();
      card.goBack(true);
    }

    cards = orderedCards.filter(c => c !== undefined);
    const component = Qt.createComponent("LunarLtk.Components", "CardItem");
    for (const model of allCards) {
      if (cards.find(e => e.dataModel === model)) continue;
      const card = component.createObject(Ltk.roomScene.dynamicCardArea, {
        x: myPos.x + width,
        y: myPos.y,
        dataModel: model,
      });
      model.selectedChanged() // 手动刷新一下
      const selectable = model.selectable;
      if (dataModel.expandedCards.includes(model)) {
        // 手牌区固定不显示脚注了，之前手牌用来显示区域或提示的文本改了个UI
        card.areaText = model.footnote;
      }
      add(card);
      model.selectable = selectable;
    }

    updateCardPosition(true);
  }

  function applyChange(uiUpdate) {
    sortable = Ltk.canSortHandcards(Cpp.self.id);

    syncCards();
  }
}
