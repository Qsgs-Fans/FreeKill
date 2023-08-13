// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.RoomElement

/* Layout of EquipArea:
 *  |    Treasure   |
    |     Weapon    |
    |     Armor     |
    |   +1  |   -1  |
    +---------------+
 */

Column {
  id: root

  height: 70
  width: 138
  property int itemHeight: (treasureItem.name === "" && !treasureItem.sealed) ? height / 3 : height / 4
  property var items: [treasureItem, weaponItem, armorItem, defensiveHorseItem, offensiveHorseItem]
  property var subtypes: ["treasure", "weapon", "armor", "defensive_horse", "offensive_horse"]
  property int length: area.length

  InvisibleCardArea {
    id: area
    anchors.centerIn: parent
    checkExisting: true
  }

  EquipItem {
    id: treasureItem
    subtype: "treasure"
    width: parent.width
    height: (name === "" && !sealed) ? 0 : itemHeight
    opacity: 0
    sealed: root.parent.sealedSlots.includes('TreasureSlot')
  }

  EquipItem {
    id: weaponItem
    subtype: "weapon"
    width: parent.width
    height: itemHeight
    opacity: 0
    sealed: root.parent.sealedSlots.includes('WeaponSlot')
  }

  EquipItem {
    id: armorItem
    subtype: "armor"
    width: parent.width
    height: itemHeight
    opacity: 0
    sealed: root.parent.sealedSlots.includes('ArmorSlot')
  }

  Row {
    width: parent.width
    height: itemHeight

    Item {
      width: Math.ceil(parent.width / 2)
      height: itemHeight

      EquipItem {
        id: defensiveHorseItem
        width: parent.width
        height: itemHeight
        icon: "horse"
        opacity: 0
        sealed: root.parent.sealedSlots.includes('DefensiveRideSlot')
      }
    }

    Item {
      width: Math.floor(parent.width / 2)
      height: itemHeight

      EquipItem {
        id: offensiveHorseItem
        width: parent.width
        height: itemHeight
        icon: "horse"
        opacity: 0
        sealed: root.parent.sealedSlots.includes('OffensiveRideSlot')
      }
    }
  }

  function add(inputs)
  {
    area.add(inputs);

    let card, item;
    if (inputs instanceof Array) {
      for (let i = 0; i < inputs.length; i++) {
        card = inputs[i];
        item = items[subtypes.indexOf(card.subtype)];
        item.setCard(card);
        item.show();
      }
    } else {
      card = inputs;
      item = items[subtypes.indexOf(card.subtype)];
      item.setCard(card);
      item.show();
    }
  }

  function remove(outputs)
  {
    const result = area.remove(outputs);
    for (let i = 0; i < result.length; i++) {
      const card = result[i];
      for (let j = 0; j < items.length; j++) {
        const item = items[j];
        if (item.cid === card.cid) {
          item.reset();
          item.hide();
        }
      }
    }

    return result;
  }

  function updateCardPosition(animated)
  {
    area.updateCardPosition(animated);
  }

  function getAllCards() {
    return area.cards;
  }
}
