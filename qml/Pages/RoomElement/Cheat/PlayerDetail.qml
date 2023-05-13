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
    width: parent.width - 16

    // TODO: player details
    Text {
      id: screenName
      Layout.fillWidth: true
      font.pixelSize: 18
    }

    TextEdit {
      id: skillDesc

      Layout.fillWidth: true
      leftPadding: 16
      font.pixelSize: 18

      readOnly: true
      selectByKeyboard: true
      selectByMouse: false
      wrapMode: TextEdit.WordWrap
      textFormat: TextEdit.RichText
    }
  }

  onExtra_dataChanged: {
    if (!extra_data.photo) return;
    screenName.text = "";
    skillDesc.text = "";

    let id = extra_data.photo.playerid;
    if (id == 0) return;

    let data = JSON.parse(Backend.callLuaFunction("GetPlayerSkills", [id]));
    data.forEach(t => {
      skillDesc.append("<b>【" + Backend.translate(t.name) + "】</b> " + t.description)
    });
  }
}
