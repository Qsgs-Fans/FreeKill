// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common

GraphicsBox {
  property var options: []
  property var all_options: []
  property bool cancelable: false
  property int min_num: 0
  property int max_num: 0
  property string skill_name: ""
  property var result: []

  id: root
  title.text: Lua.tr("$Choice").arg(Lua.tr(skill_name))
  width: Math.max(140, body.width + 20)
  height: buttons.height + body.height + title.height + 20

  GridLayout {
    id: body
    // x: 10
    anchors.horizontalCenter: parent.horizontalCenter
    y: title.height + 5
    flow: GridLayout.TopToBottom
    rows: 8
    columnSpacing: 10

    Repeater {
      model: all_options

      MetroToggleButton {
        Layout.fillWidth: true
        text: Util.processPrompt(modelData)
        enabled: options.indexOf(modelData) !== -1
                 && (root.result.length < max_num || triggered)

        onClicked: {
          if (triggered) {
            root.result.push(index);
          } else {
            root.result.splice(root.result.indexOf(index), 1);
          }
          root.resultChanged();
        }
      }
    }
  }

  Row {
    id: buttons
    anchors.margins: 8
    anchors.top: body.bottom
    anchors.horizontalCenter: root.horizontalCenter
    spacing: 32

    MetroButton {
      Layout.fillWidth: true
      text: Lua.tr("OK")
      enabled: root.result.length >= min_num

      onClicked: {
        root.close();
      }
    }

    MetroButton {
      Layout.fillWidth: true
      text: Lua.tr("Cancel")
      visible: cancelable

      onClicked: {
        root.result = [];
        root.close();
      }
    }
  }
}
