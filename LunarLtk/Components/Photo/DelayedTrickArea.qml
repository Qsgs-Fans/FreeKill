// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import LunarLtk
import LunarLtk.Components

Item {
  id: root
  required property PhotoModel dataModel
  property bool sealed: dataModel.sealedSlots.includes("JudgeSlot")

  Image {
    visible: root.sealed
    x: -6; y: 8; z: 9
    source: SkinBank.delayedTrickDir + "sealed"
    height: 21
    fillMode: Image.PreserveAspectFit
  }

  InvisibleCardArea {
    id: area
  }

  Row {
    id: grid
    anchors.fill: parent
    spacing: -4

    Repeater {
      model: {
        const cards = root.dataModel.delayedTricks;
        const lens = {};
        let ret = [];
        for (const card of cards) {
          let name = card.name;
          const vcardData = Ltk.getVirtualEquipData(root.dataModel.playerid, card.cardId);
          if (vcardData) {
            name = vcardData.name;
          }
          if (!lens[name]) ret.push(name);
          lens[name] = lens[name] ?? 0;
          ++lens[name];
        }
        return ret.map(name => ({ cardName: name, length: lens[name] }));
      }

      Item {
        required property var modelData
        height: 55 * 0.6
        width: 47 * 0.6
        Image {
          anchors.fill: parent
          source: SkinBank.getDelayedTrickPicture(parent.modelData.cardName);
          fillMode: Image.PreserveAspectFit
        }

        Text { // 右下角的数量，1省略
          anchors.right: parent.right
          anchors.rightMargin: 5
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 5
          text: parent.modelData.length
          visible: parent.modelData.length > 1
          font.family: Config.libianName
          font.pixelSize: 20
          font.bold: true
          color: "white"
          style: Text.Outline
        }
      }
    }
  }

  function add(inputs) { area.add(inputs); }
  function remove(outputs) { return area.remove(outputs); }
  function updateCardPosition(animated) { area.updateCardPosition(animated); }
}
