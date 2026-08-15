// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import LunarLtk
import LunarLtk.Components
import LunarLtk.Models.Popups

GraphicsBox {
  id: root

  required property AGModel dataModel

  property int spacing: 5

  title.text: dataModel.promptText
  width: dataModel.cards.length * 100 + spacing * (dataModel.cards.length - 1) + 25
  height: 180

  Row {
    x: 20
    y: 35
    spacing: root.spacing

    Repeater {
      model: root.dataModel.cards

      CardItem {
        required property var modelData
        dataModel: modelData
        autoBack: false
        footnoteVisible: true
        onClicked: {
          root.dataModel.selectCard(modelData);
        }
      }
    }
  }
}
