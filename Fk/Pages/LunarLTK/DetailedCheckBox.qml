// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

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

  ListView {
    id: body
    x: 10
    y: title.height + 5
    width: Math.min(700, 220 * model.length)
    height: 300
    orientation: ListView.Horizontal
    clip: true
    spacing: 20

    model: all_options

    delegate: Item {
      width: 200
      height: 290

      MetroToggleButton {
        id: choicetitle
        width: parent.width
        text: Lua.tr(modelData)
        triggered: root.result.includes(index)
        enabled: options.indexOf(modelData) !== -1
                 && (root.result.length < max_num || triggered)
        textFont.pixelSize: 24
        anchors.top: choiceDetail.bottom
        anchors.topMargin: 8

        onClicked: {
          if (triggered) {
            root.result.push(index);
          } else {
            root.result.splice(root.result.indexOf(index), 1);
          }
          root.result = root.result;
        }
      }

      Flickable {
        id: choiceDetail
        x: 4
        height: parent.height - choicetitle.height
        contentHeight: detail.height
        width: parent.width
        clip: true
        Text {
          id: detail
          width: parent.width
          text: Lua.tr(":" + modelData)
          color: "white"
          wrapMode: Text.WordWrap
          font.pixelSize: 16
          textFormat: TextEdit.RichText
        }
      }
    }
  }

  Row {
    id: buttons
    anchors.margins: 8
    anchors.bottom: root.bottom
    anchors.horizontalCenter: root.horizontalCenter
    spacing: 32

    MetroButton {
      width: 120
      height: 35
      text: Lua.tr("OK")
      enabled: root.result.length >= min_num

      onClicked: {
        root.close();
      }
    }

    MetroButton {
      width: 120
      height: 35
      text: Lua.tr("Cancel")
      visible: root.cancelable

      onClicked: {
        result = [];
        root.close();
      }
    }
  }
}
