import QtQuick

InvisibleItemArea {
  id: root

  function remove(toRemove, compareFn) {
    let result = [];
    for (let j = 0; j < toRemove.length; j++) {
      for (let i = items.length - 1; i >= 0; i--) {
        if (compareFn(toRemove[j], items[i])) {
          result.push(items[i]);
          items.splice(i, 1);
          i--;
          break;
        }
      }
    }
    length = items.length;
    return result;
  }

  function updatePosition(animated) {
    let i, card;

    let overflow = false;
    for (i = 0; i < items.length; i++) {
      card = items[i];
      card.origX = i * card.width;
      if (card.origX + card.width >= root.width) {
        overflow = true;
        break;
      }
      card.origY = 0;
    }

    if (overflow) {
      const xLimit = root.width - card.width;
      const spacing = xLimit / (items.length - 1);
      for (i = 0; i < items.length; i++) {
        card = items[i];
        card.origX = i * spacing;
        card.origY = 0;
        card.z = i + 1;
        card.initialZ = i + 1;
        card.maxZ = items.length;
      }
    }

    const parentPos = scene.mapFromItem(root, 0, 0);
    for (i = 0; i < items.length; i++) {
      card = items[i];
      card.origX += parentPos.x;
      card.origY += parentPos.y;
    }

    if (animated) {
      for (i = 0; i < items.length; i++) {
        if (!items[i].dragging) items[i].goBack(true);
      }
    }
  }
}
