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
    if (!extra_data.generals) return;
    skillDesc.text = "";

    extra_data.generals.forEach((g) => {
      let data = JSON.parse(Backend.callLuaFunction("GetGeneralDetail", [g]));
      skillDesc.append(Backend.translate(data.kingdom) + " " + Backend.translate(g) + " " + data.hp + "/" + data.maxHp);
      data.skill.forEach(t => {
        skillDesc.append("<b>" + Backend.translate(t.name) + "</b>: " + t.description)
      });
      data.related_skill.forEach(t => {
        skillDesc.append("<font color=\"purple\"><b>" + Backend.translate(t.name) + "</b>: " + t.description + "</font>")
      });
      skillDesc.append("\n");
    });
  }
}
