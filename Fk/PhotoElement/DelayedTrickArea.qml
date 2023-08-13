// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.RoomElement

Item {
  property bool sealed: parent.sealedSlots.includes("JudgeSlot")

  Image {
    visible: sealed
    x: -6; y: 8; z: 9
    source: SkinBank.DELAYED_TRICK_DIR + "sealed"
    height: 28
    fillMode: Image.PreserveAspectFit
  }

  InvisibleCardArea {
    id: area
    checkExisting: true
  }

  ListModel {
    id: cards
  }

  Row {
    id: grid
    anchors.fill: parent
    spacing: -4

    Repeater {
      model: cards

      Image {
        height: 55 * 0.8
        width: 47 * 0.8
        source: SkinBank.getDelayedTrickPicture(name) // SkinBank.DELAYED_TRICK_DIR + name
      }
    }
  }

  function add(inputs)
  {
    area.add(inputs);
    if (!(inputs instanceof Array)) {
      inputs = [inputs];
    }
    inputs.forEach(card => {
      const v = JSON.parse(Backend.callLuaFunction("GetVirtualEquip", [parent.playerid, card.cid]));
      if (v !== null) {
        cards.append(v);
      } else {
        cards.append({
          name: card.name,
          cid: card.cid
        });
      }
    });
  }

  function remove(outputs)
  {
    const result = area.remove(outputs);
    for (let i = 0; i < result.length; i++) {
      const item = result[i];
      for (let j = 0; j < cards.count; j++) {
        const icon = cards.get(j);
        if (icon.cid === item.cid) {
          cards.remove(j, 1);
          break;
        }
      }
    }

    return result;
  }

  function updateCardPosition(animated)
  {
    area.updateCardPosition(animated);
  }
}
