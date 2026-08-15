// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk
import LunarLtk

RowLayout {
  id: root
  spacing: 4

  required property var markModel

  Repeater {
    id: markRepeater
    model: root.markModel

    Item {
      id: markItem
      required property var modelData
      // 垃圾QML这又是出什么bug了ListModel抹掉元素能出个undefined的modelData是吧
      readonly property var _m: modelData ?? { origName: "", desc: "", value: "" }
      width: 21
      height: 21
      Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: SkinBank.getMarkPic(parent._m.origName)

        MouseArea { // 鼠标经过时显示文字，单击固定
          id: markArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: markItem._m.desc !== ""
          onEntered: {
            descriptionTip.visible = true;
          }
          onExited: {
            descriptionTip.visible = descriptionTip.clicked;
          }
          onClicked: {
            descriptionTip.visible = true;
            descriptionTip.clicked = true;
          }
        }
        ToolTip {
          id: descriptionTip
          x: 20
          y: 20
          text: markItem._m.desc;
          visible: false
          property bool clicked: false
          font.family: Config.libianName
          font.pixelSize: 20
        }
      }

      Text { // 右下角的文字，单个为翻译，1省略，数组为数量
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: markItem._m.value
        visible: markItem._m.value && markItem._m.value !== "1"
        font.family: Config.libianName
        font.pixelSize: 20
        font.bold: true
        color: "white"
        style: Text.Outline
      }
    }
  }
}
