// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
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
      width: 28
      height: 28
      Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: SkinBank.getMarkPic(mark_name)
      }

      Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: mark_extra
        visible: mark_extra != 1
        font.family: fontLibian.name
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

    if (modelItem) {
      modelItem.mark_extra = data;
    } else {
      markList.append({ mark_name: mark, mark_extra: data });
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
