import QtQuick

Item {
  id: root

  property list<Item> items: []
  property int length: 0

  required property Item scene

  function add(inputs) {
    if (inputs instanceof Array) {
      items.push(...inputs);
    } else {
      items.push(inputs);
    }

    length = items.length;
  }

  function remove(datas, outputParent) {
    const parentPos = scene.mapFromItem(root, 0, 0);
    const items = [];
    for (let i = 0; i < datas.length; i++) {
      const d = datas[i];
      const component = d.path === undefined ? Qt.createComponent(d.uri, d.name) : Qt.createComponent(d.path);
      const state = d.prop;
      state.x = parentPos.x;
      state.y = parentPos.y;
      state.opacity = 0;

      const item = component.createObject(outputParent, state);
      item.x -= item.width / 2;
      item.x += (i - datas.length / 2) * 15;
      item.y -= item.height / 2;
      items.push(item);
    }

    return items;
  }

  function updatePosition(animated) {
    let i, card;

    const parentPos = scene.mapFromItem(root, 0, 0);
    if (animated) {
      for (i = 0; i < items.length; i++) {
        card = items[i];
        card.origX = parentPos.x - card.width / 2
        + ((i - items.length / 2) * 15);
        card.origY = parentPos.y - card.height / 2;
        card.origOpacity = 0;
        card.destroyOnStop();
      }

      for (i = 0; i < items.length; i++)
      items[i].goBack(true);
    } else {
      for (i = 0; i < items.length; i++) {
        card = items[i];
        card.x = parentPos.x - card.width / 2;
        card.y = parentPos.y - card.height / 2;
        card.opacity = 1;
        card.destroy();
      }
    }

    items = [];
    length = 0;
  }
}
