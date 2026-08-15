// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk.Components.GameCommon as Game

import LunarLtk

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

  function remove(outputs) {
    const datas = [];

    for (const dataModel of outputs) {
      datas.push({
        uri: "LunarLtk.Components",
        name: "CardItem",
        prop: { dataModel },
      })
    }

    area.lengthChanged(); // 唉

    return area.remove(datas, roomScene.dynamicCardArea);
  }

  function updateCardPosition(animated) {
    area.updatePosition(animated);
  }
}
