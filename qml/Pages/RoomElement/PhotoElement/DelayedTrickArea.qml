// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import ".."
import "../../skin-bank.js" as SkinBank

Item {
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
        source: SkinBank.DELAYED_TRICK_DIR + name
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
      let v = JSON.parse(Backend.callLuaFunction("GetVirtualEquip", [parent.playerid, card.cid]));
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
    let result = area.remove(outputs);
    for (let i = 0; i < result.length; i++) {
      let item = result[i];
      for (let j = 0; j < cards.count; j++) {
        let icon = cards.get(j);
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
