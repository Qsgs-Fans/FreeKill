// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common

import LunarLtk.Components
import LunarLtk.Models.Popups

pragma ComponentBehavior: Bound

GraphicsBox {
  id: root

  required property PoxiModel dataModel

  title.text: dataModel.promptText

  // TODO: Adjust the UI design in case there are more than 7 cards
  width: 70 + 700
  height: 64 + Math.min(cardView.contentHeight, 400) + 30

  ListView {
    id: cardView
    anchors.fill: parent
    anchors.topMargin: 40
    anchors.leftMargin: 20
    anchors.rightMargin: 20
    anchors.bottomMargin: 30
    spacing: 20
    model: root.dataModel.cardData
    clip: true

    delegate: RowLayout {
      id: cardRow
      spacing: 15
      required property var modelData

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
            autoBack: false
            selectable: chosenInBox || root.dataModel.cardFilter(modelData)

            onSelectedChanged: {
              if (selected) {
                chosenInBox = true;
                root.dataModel.selectedIds.push(modelData);
              } else {
                chosenInBox = false;
                root.dataModel.selectedIds.splice(root.dataModel.selectedIds.indexOf(modelData), 1);
              }
            }
          }
        }
      }
    }
  }

  Item {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
    height: 35

    MetroButton {
      width: 90
      height: 35
      anchors.left: parent.left
      anchors.leftMargin: 60
      text: Lua.tr("Revert Selection")
      onClicked: root.dataModel.revertSelection()
    }

    MetroButton { // OK button must be centered
      id : okButton
      width: 140
      height: 35
      anchors.centerIn: parent
      text: Lua.tr("OK")
      enabled: root.dataModel.feasible
      onClicked: root.dataModel.accepted()
    }

    MetroButton {
      width: 90
      height: 35
      anchors.left: okButton.right
      anchors.leftMargin: 100
      text: Lua.tr("Cancel")
      visible: root.dataModel.cancelable
      onClicked: root.dataModel.rejected()
    }
  }
}
