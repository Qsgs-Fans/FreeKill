// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

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

      MetroButton {
        id: choicetitle
        width: parent.width
        text: Lua.tr(modelData)
        enabled: options.indexOf(modelData) !== -1
        textFont.pixelSize: 24
        anchors.top: choiceDetail.bottom
        anchors.topMargin: 8

        onClicked: {
          result = index;
          root.close();
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
          text: {
            let translated = Lua.tr(":" + modelData);
            return translated === (":" + modelData) ? Lua.tr(modelData) : translated;
          }
          color: "white"
          wrapMode: Text.WordWrap
          font.pixelSize: 16
          textFormat: TextEdit.RichText
        }
      }
    }
  }
}
