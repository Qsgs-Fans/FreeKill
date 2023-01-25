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
          card.origOpacity = 0;
          card.goBack(true);
          card.destroyOnStop()
        }

        cards.splice(0, discardedCards.length);
        updateCardPosition(true);

        discardedCards = new Array(cards.length);
        for (i = 0; i < cards.length; i++)
          discardedCards[i] = cards[i];
        toVanish = false
      } else {
        for (i = 0; i < discardedCards.length; i++) {
          discardedCards[i].selectable = false
        }
        toVanish = true
      }
    }
  }

  function add(inputs)
  {
    area.add(inputs);
    // if (!inputs instanceof Array)
    for (let i = 0; i < inputs.length; i++) {
      inputs[i].footnoteVisible = true;
      inputs[i].selectable = true;
      inputs[i].height = inputs[i].height * 0.8;
      inputs[i].width = inputs[i].width * 0.8;
      inputs[i].rotation = (Math.random() - 0.5) * 5;
    }
  }

  function remove(outputs)
  {
    let i, j;

    let result = area.remove(outputs);
    for (let i = 0; i < result.length; i++) {
      inputs[i].footnoteVisible = false;
      inputs[i].selectable = false;
      inputs[i].height = inputs[i].height / 0.8;
      inputs[i].width = inputs[i].width / 0.8;
      inputs[i].rotation = 0;
    }
    let vanished = [];
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
      let xLimit = root.width - card.width;
      let spacing = xLimit / (cards.length - 1);
      for (i = 0; i < cards.length; i++) {
        card = cards[i];
        card.origX = i * spacing;
        card.origY = 0;
      }
    }

    let offsetX = Math.max(0, (root.width - cards.length * card.width) / 2);
    let parentPos = roomScene.mapFromItem(root, 0, 0);
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
