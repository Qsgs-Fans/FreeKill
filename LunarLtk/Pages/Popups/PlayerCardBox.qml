// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk

import LunarLtk.Components
import LunarLtk.Models.Popups

pragma ComponentBehavior: Bound

GraphicsBox {
  id: root

  required property PlayerCardModel dataModel

  title.text: dataModel.promptText || Lua.tr("$ChooseCard")

  // TODO: Adjust the UI design in case there are more than 7 cards
  width: 70 + 700
  height: 64 + Math.min(cardView.contentHeight, 400)

  ListView {
    id: cardView
    anchors.fill: parent
    anchors.topMargin: 40
    anchors.leftMargin: 20
    anchors.rightMargin: 20
    anchors.bottomMargin: 20
    spacing: 20
    model: root.dataModel.shuffleIds()
    clip: true

    delegate: RowLayout {
      required property var modelData
      id: cardRow
      spacing: 15
      visible: cardRow.modelData[1].length > 0

      PoxiLabel {
        Layout.alignment: Qt.AlignVCenter
        text: Lua.tr(cardRow.modelData[0])
      }

      GridLayout {
        columns: 7
        Repeater {
          model: cardRow.modelData[1]

          CardItem {
            required property int modelData
            dataModel: root.dataModel.cardModels[modelData]
            selectable: true
            onClicked: {
              root.dataModel.selectedId = modelData;
              root.dataModel.accepted();
            }
          }
        }
      }
    }
  }
}
