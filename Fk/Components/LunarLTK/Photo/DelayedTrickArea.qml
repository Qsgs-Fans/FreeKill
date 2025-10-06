// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.LunarLTK

Item {
  property bool sealed: parent.sealedSlots.includes("JudgeSlot")
  property var cids: ({})

  Image {
    visible: sealed
    x: -6; y: 8; z: 9
    source: SkinBank.delayedTrickDir + "sealed"
    height: 21
    fillMode: Image.PreserveAspectFit
  }

  InvisibleCardArea {
    id: area
    // checkExisting: true
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

      Item {
        height: 55 * 0.6
        width: 47 * 0.6
        Image {
          anchors.fill: parent
          source: SkinBank.getDelayedTrickPicture(name)
          fillMode: Image.PreserveAspectFit
        }

        Text { // 右下角的数量，1省略
          anchors.right: parent.right
          anchors.rightMargin: 5
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 5
          text: len
          visible: len > 1
          font.family: Config.libianName
          font.pixelSize: 20
          font.bold: true
          color: "white"
          style: Text.Outline
        }
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
      const v = Lua.call("GetVirtualEquipData", parent.playerid, card.cid);
      let icon;
      const cardName = v ? v.name : card.name;
      for (let i = 0; i < cards.count; i++) {
        const currentItem = cards.get(i);
        if (currentItem.name === cardName) {
          icon = currentItem;
          break;
        }
      }
      if (cids[cardName] === undefined) {
        cids[cardName] = [];
      }
      cids[cardName].push(v ? v.cid : card.cid);
      if (!icon) {
        cards.append({ name: cardName, len: 1 });
      } else {
        icon.len = cids[cardName].length;
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
        const index = cids[icon.name].indexOf(item.cid);
        if (index !== -1) {
          cids[icon.name].splice(index, 1);
          if (cids[icon.name].length === 0) {
            cards.remove(j, 1);
          } else {
            icon.len = cids[icon.name].length;
          }
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
