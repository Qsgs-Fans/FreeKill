// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk.Pages

GraphicsBox {
  property var options: []
  property string skill_name: ""
  property int result

  id: root
  title.text: Backend.translate("$Choice").arg(Backend.translate(skill_name))
  width: Math.max(140, body.width + 20)
  height: body.height + title.height + 20

  GridLayout {
    id: body
    x: 10
    y: title.height + 5
    flow: GridLayout.TopToBottom
    rows: 8
    columnSpacing: 10

    Repeater {
      model: options

      MetroButton {
        Layout.fillWidth: true
        text: Backend.translate(modelData)

        onClicked: {
          result = index;
          root.close();
        }
      }
    }
  }
}
