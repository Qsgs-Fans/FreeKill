// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import Fk.Components.GameCommon as Game

Item {
  id: root

  property alias cards: area.items
  property alias length: area.length

  Game.InvisibleItemArea {
    id: area
    scene: roomScene
  }

  function add(inputs) {
    area.add(inputs);
  }

  function remove(outputs, _, visibleData) {
    const component = Qt.createComponent("CardItem.qml");
    if (component.status !== Component.Ready)
      return [];

    const datas = [];

    for (let i = 0; i < outputs.length; i++) {
      const prop = Lua.call("GetCardData", outputs[i]);
      if (visibleData) prop.known = !!visibleData[outputs[i].toString()];

      datas.push({
        uri: "Fk.Components.LunarLTK",
        name: "CardItem",
        prop,
      })
    }

    area.lengthChanged(); // 唉

    return area.remove(datas, roomScene.dynamicCardArea);
  }

  function updateCardPosition(animated) {
    area.updatePosition(animated);
  }
}
