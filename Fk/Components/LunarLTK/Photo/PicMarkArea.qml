// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk

RowLayout {
  id: root
  spacing: 4

  ListModel {
    id: markList
  }

  Repeater {
    id: markRepeater
    model: markList

    Item {
      width: 21
      height: 21
      Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: SkinBank.getMarkPic(mark_name)

        MouseArea{ // 鼠标经过时显示文字，单击固定
          id: markArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: mark_extra !== ""
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
          text: mark_extra
          visible: false
          property bool clicked: false
          font.family: Config.libianName
          font.pixelSize: 20
        }
      }

      Text { // 右下角的文字，单个为翻译，1省略，数组为数量
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: special_value
        visible: special_value !== ""
        font.family: Config.libianName
        font.pixelSize: 20
        font.bold: true
        color: "white"
        style: Text.Outline
      }
    }
  }

  function setMark(mark, data) {
    let i, modelItem;
    for (i = 0; i < markList.count; i++) {
      if (markList.get(i).mark_name === mark) {
        modelItem = markList.get(i);
        break;
      }
    }
    let special_value = '';

    if (data instanceof Array) {
      special_value += data.length;
      data = data.map((markText) => Lua.tr(markText)).join('<br>');
    } else {
      data = data === '1' ? '' : Lua.tr(data);
      special_value += data;
    }

    if (mark.startsWith('@!!')) { // @!! 追加翻译标记名和描述
      data = '<b>' + Lua.tr(mark) + '</b>' + '<br>' + Lua.tr(":" + mark) + (data === '' ? '' : '<br>' + data);
    }

    if (modelItem) { // 如果已经存在
      modelItem.special_value = special_value;
      modelItem.mark_extra = data;
    } else {
      markList.append({ mark_name: mark, mark_extra: data, special_value }); // special_value 传数量， mark_extra 传内容（翻译后的）
    }
  }

  function removeMark(mark) {
    let i, modelItem;
    for (i = 0; i < markList.count; i++) {
      if (markList.get(i).mark_name === mark) {
        markList.remove(i, 1);
        return;
      }
    }
  }
}
