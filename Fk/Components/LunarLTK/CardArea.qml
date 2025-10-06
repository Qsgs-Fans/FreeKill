// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import Fk.Components.GameCommon as Game

Item {
  id: root

  property alias cards: area.items
  property alias length: area.length

  Game.ItemArea {
    id: area
    anchors.fill: parent
    scene: roomScene
  }

  function add(inputs) {
    area.add(inputs);
  }

  function remove(outputs) {
    let result = area.remove(outputs, (a, b) => a === b.cid);
    for (const cd of result) {
      const state = Lua.call("GetCardData", cd.cid);
      cd.setData(state);
    }
    return result;
  }

  function updateCardPosition(animated) {
    area.updatePosition(animated);
  }
}
