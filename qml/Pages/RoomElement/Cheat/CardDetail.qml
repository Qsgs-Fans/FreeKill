// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
  id: root
  anchors.fill: parent
  property var extra_data: ({})

  signal finish()

  contentHeight: details.height
  ScrollBar.vertical: ScrollBar {}

  ColumnLayout {
    id: details
    width: parent.width - 40
    x: 20

    // TODO: player details
    Text {
      id: screenName
      Layout.fillWidth: true
      font.pixelSize: 18
    }

    TextEdit {
      id: skillDesc

      Layout.fillWidth: true
      font.pixelSize: 18

      readOnly: true
      selectByKeyboard: true
      selectByMouse: false
      wrapMode: TextEdit.WordWrap
      textFormat: TextEdit.RichText
    }
  }

  onExtra_dataChanged: {
    const card = extra_data.card;
    if (!card) return;
    const name = card.virt_name ? card.virt_name : card.name;
    screenName.text = Backend.translate(name);
    skillDesc.text = Backend.translate(":" + name);
  }
}
