// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common

GraphicsBox {
  property var options: []
  property var all_options: []
  property string skill_name: ""
  property int result

  id: root
  title.text: Lua.tr("$Choice").arg(Lua.tr(skill_name))
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
      model: all_options

      MetroButton {
        Layout.fillWidth: true
        text: Util.processPrompt(modelData)
        enabled: options.indexOf(modelData) !== -1

        onClicked: {
          result = index;
          root.close();
        }
      }
    }
  }
}
