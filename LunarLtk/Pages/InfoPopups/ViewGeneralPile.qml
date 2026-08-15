// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import LunarLtk.Components
import LunarLtk

ColumnLayout {
  id: root
  anchors.fill: parent

  property string name
  property list<string> cardNames
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

    model: root.cardNames

    delegate: GeneralCardItem {
      required property string modelData
      id: cardItem
      autoBack: false
      dataModel: Ltk.createGeneralCardModel(modelData)
      onClicked: { // FIXME: rightClicked不能覆写
        Ltk.roomScene.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "GeneralDetail"), { generals: [modelData] });
      }
    }
  }
}
