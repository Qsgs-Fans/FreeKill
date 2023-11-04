// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk.Pages

GraphicsBox {
  property var options: []
  property var all_options: []
  property bool cancelable: false
  property int min_num: 0
  property int max_num: 0
  property string skill_name: ""
  property var result: []

  id: root
  title.text: Backend.translate("$Choice").arg(Backend.translate(skill_name))
  width: Math.max(140, body.width + 20)
  height: buttons.height + body.height + title.height + 20

  function processPrompt(prompt) {
    const data = prompt.split(":");
    let raw = Backend.translate(data[0]);
    const src = parseInt(data[1]);
    const dest = parseInt(data[2]);
    if (raw.match("%src")) raw = raw.replace(/%src/g, Backend.translate(getPhoto(src).general));
    if (raw.match("%dest")) raw = raw.replace(/%dest/g, Backend.translate(getPhoto(dest).general));
    if (raw.match("%arg2")) raw = raw.replace(/%arg2/g, Backend.translate(data[4]));
    if (raw.match("%arg")) raw = raw.replace(/%arg/g, Backend.translate(data[3]));
    return raw;
  }

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
        // Layout.fillWidth: true
        text: processPrompt(modelData)
        enabled: options.indexOf(modelData) !== -1 && (root.result.length < max_num || triggered)

        onClicked: {
          if (triggered) {
            root.result.push(index);
          } else {
            root.result.splice(root.result.indexOf(index), 1);
          }
          root.result = root.result;
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
      text: processPrompt("OK")
      enabled: root.result.length >= min_num

      onClicked: {
        root.close();
      }
    }

    MetroButton {
      Layout.fillWidth: true
      text: processPrompt("Cancel")
      visible: cancelable

      onClicked: {
        root.result = [];
        root.close();
      }
    }
  }
}
