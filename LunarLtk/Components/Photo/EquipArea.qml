// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import LunarLtk
import LunarLtk.Components

/* Layout of EquipArea:
 *  |    Treasure   |
    |     Weapon    |
    |     Armor     |
    |   +1  |   -1  |
    +---------------+
 */

Item {
  id: root

  height: 53
  width: 103

  required property PhotoModel dataModel

  property int itemHeight: {
    if (treasureItem.equips.length === 0 && !treasureItem.sealed)
      return height / 3;
    return height / 4;
  }
  property var items: [treasureItem, weaponItem, armorItem,
    defensiveHorseItem, offensiveHorseItem]
  property var subtypes: ["treasure", "weapon", "armor",
    "defensive_ride", "offensive_ride"]
  property int length: 0

  Column {
    anchors.fill: parent
    InvisibleCardArea {
      id: area
      anchors.centerIn: parent
      // checkExisting: true
      onLengthChanged: {
        root.length = root.dataModel.luaPlayer.getCardIds("e").length;
      }
    }

    EquipItem {
      id: treasureItem
      subtype: "treasure"
      width: parent.width
      height: (equips.length === 0 && !sealed) ? 0 : itemHeight
      opacity: 0
      sealed: root.dataModel.sealedSlots.includes('TreasureSlot')
    }

    EquipItem {
      id: weaponItem
      subtype: "weapon"
      width: parent.width
      height: itemHeight
      opacity: 0
      sealed: root.dataModel.sealedSlots.includes('WeaponSlot')
    }

    EquipItem {
      id: armorItem
      subtype: "armor"
      width: parent.width
      height: itemHeight
      opacity: 0
      sealed: root.dataModel.sealedSlots.includes('ArmorSlot')
    }

    Row {
      width: root.width
      height: itemHeight

      Item {
        width: Math.ceil(parent.width / 2)
        height: itemHeight

        EquipItem {
          id: defensiveHorseItem
          width: parent.width
          height: itemHeight
          subtype: "defensive_ride"
          opacity: 0
          sealed: root.dataModel.sealedSlots.includes('DefensiveRideSlot')
        }
      }

      Item {
        width: Math.floor(parent.width / 2)
        height: itemHeight

        EquipItem {
          id: offensiveHorseItem
          width: parent.width
          height: itemHeight
          subtype: "offensive_ride"
          opacity: 0
          sealed: root.dataModel.sealedSlots.includes('OffensiveRideSlot')
        }
      }
    }
  }

  function add(inputs) {
    area.add(inputs);

    for (const card of inputs instanceof Array ? inputs : [inputs]) {
      const vcardData = Ltk.getVirtualEquipData(dataModel.playerid, card.dataModel.cardId);
      if (vcardData) {
        delete vcardData.cid;
        Object.assign(card.dataModel, vcardData);
      }
      const item = items[subtypes.indexOf(card.dataModel.subtype)];
      if (item) {
        item.addCard(card.dataModel);
        item.show();
      }
    }
  }

  function remove(outputs) {
    const result = area.remove(outputs);
    for (const card of result) {
      for (const item of items) {
        item.removeCard(card.dataModel.cardId);
      }
    }

    return result;
  }

  function updateCardPosition(animated) {
    area.updateCardPosition(animated);
  }

  function getAllCards() {
    return area.cards;
  }
}
