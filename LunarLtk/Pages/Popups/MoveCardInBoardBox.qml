// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common

import LunarLtk
import LunarLtk.Components
import LunarLtk.Models.Popups

pragma ComponentBehavior: Bound

GraphicsBox {
  id: root
  required property MoveCardInBoardModel dataModel

  property int padding: 25

  title.text: Lua.tr("Please click to move card")
  width: body.width + padding * 2
  height: title.height + body.height + padding * 2

  onShown: arrangeCards();

  ColumnLayout {
    id: body
    x: root.padding
    y: parent.height - root.padding - height
    spacing: 20

    Repeater {
      id: areaRepeater
      model: root.dataModel.playerIds

      Row {
        spacing: 5
        required property string modelData

        PoxiLabel {
          Layout.alignment: Qt.AlignVCenter
          text: Lua.tr(Ltk.getPlayerStr(parent.modelData))
        }

        Repeater {
          model: root.dataModel.cardIds

          Rectangle {
            required property int modelData
            color: "#4A4139"
            width: 93
            height: 130
            opacity: 0.5

            Text {
              horizontalAlignment: Text.AlignHCenter
              anchors.centerIn: parent
              text: Lua.tr(root.dataModel.cardModels[parent.modelData].subtype)
              color: "#90765F"
              font.family: Config.libianName
              font.pixelSize: 16
              width: parent.width * 0.8
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }

    MetroButton {
      Layout.alignment: Qt.AlignHCenter
      id: buttonConfirm
      text: Lua.tr("OK")
      implicitWidth: 120
      implicitHeight: 35
      enabled: root.dataModel.feasible
      onClicked: root.dataModel.accepted()
    }
  }

  Repeater {
    id: cardItems
    model: root.dataModel.cardIds

    CardItem {
      required property int modelData
      dataModel: root.dataModel.cardModels[modelData]

      selectable: {
        const result = root.dataModel.result;
        return result === -1 || result === modelData;
      }
      onClicked: {
        if (!selectable) return;
        if (root.dataModel.result === modelData) {
          root.dataModel.result = -1;
        } else {
          root.dataModel.result = modelData;
        }

        root.arrangeCards();
      }
    }
  }

  function arrangeCards() {
    for (let i = 0; i < cardItems.count; i++) {
      const cd = cardItems.itemAt(i) as CardItem;
      cd.origX = i * 98 + 50;
      cd.origY = body.y;

      const pos = root.dataModel.cardsPosition[i];
      const selected = root.dataModel.result === cd.dataModel.cardId;
      if (pos ^ selected) {
        cd.origY += 150;
      }
      cd.goBack(true);
    }
  }
}
