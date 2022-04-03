import QtQuick 2.15
import ".."
import "../../skin-bank.js" as SkinBank

/* Layout of EquipArea:
 *  |    Treasure   |
    |     Weapon    |
    |     Armor     |
    |   +1  |   -1  |
    +---------------+
 */

Column {
    height: 88
    width: 138
    property int itemHeight: Math.floor(height / 4)
    property var items: [treasureItem, weaponItem, armorItem, defensiveHorseItem, offensiveHorseItem]
    property var subtypes: ["treasure", "weapon", "armor", "defensive_horse", "offensive_horse"]
    property int length: area.length

    InvisibleCardArea {
        id: area
        checkExisting: true
    }

    EquipItem {
        id: treasureItem
        width: parent.width
        height: itemHeight
        opacity: 0
    }

    EquipItem {
        id: weaponItem
        width: parent.width
        height: itemHeight
        opacity: 0
    }

    EquipItem {
        id: armorItem
        width: parent.width
        height: itemHeight
        opacity: 0
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
            }
        }
    }

    function add(inputs)
    {
        area.add(inputs);

        var card, item;
        if (inputs instanceof Array) {
            for (var i = 0; i < inputs.length; i++) {
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
        var result = area.remove(outputs);
        for (var i = 0; i < result.length; i++) {
            var card = result[i];
            for (var j = 0; j < items.length; j++) {
                var item = items[j];
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
}

