// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import LunarLtk
import LunarLtk.Components

ColumnLayout {
  id: root
  anchors.fill: parent

  property string name
  property list<int> ids
  property list<string> cardNames
  property var additional_prop

  signal finish()

  BigGlowText {
    Layout.fillWidth: true
    Layout.preferredHeight: childrenRect.height + 4

    text: Lua.tr(root.name)
  }

  GridView {
    cellWidth: 93 + 4
    cellHeight: 130 + 4
    Layout.preferredWidth: root.width - root.width % 97
    Layout.fillHeight: true
    Layout.alignment: Qt.AlignHCenter
    clip: true

    model: root.ids.length > 0 ? root.ids : root.cardNames

    delegate: CardItem {
      id: cardItem
      required property var modelData
      autoBack: false
      dataModel: {
        if (typeof modelData === "string") {
          return Ltk.createCardModelFromName(modelData, root.additional_prop ?? { selectable: true });
        } else {
          return Ltk.createCardModel(modelData, root.additional_prop ?? { selectable: true });
        }
      }
    }
  }
}
