// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

Item {
  id: root
  width: 138

  ListModel {
    id: markList
  }

  Rectangle {
    anchors.bottom: parent.bottom
    width: parent.width
    height: parent.height
    color: "#3C3229"
    opacity: 0.8
    radius: 4
    border.color: "white"
    border.width: 1

    Behavior on height {
      NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
    }
  }

  Repeater {
    id: markRepeater
    model: markList
    Item {
      width: childrenRect.width
      height: 22
      Text {
        text: Backend.translate(mark_name) + ' ' + (special_value !== '' ? special_value : mark_extra)
        font.family: fontLibian.name
        font.pixelSize: 22
        font.letterSpacing: -0.6
        color: "white"
        style: Text.Outline
        textFormat: Text.RichText
      }

      Behavior on x {
        NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
      }

      Behavior on y {
        NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
      }

      TapHandler {
        enabled: root.parent.state != "candidate" || !root.parent.selectable
        onTapped: {
          const params = { name: mark_name };

          if (mark_name.startsWith('@&')) {
            params.cardNames = mark_extra.split(',');
            roomScene.startCheat("../RoomElement/ViewGeneralPile", params);
            return;
          }

          if (mark_name.startsWith('@$')) {
            params.cardNames = mark_extra.split(',');
          } else {
            let data = JSON.parse(Backend.callLuaFunction("GetPile", [root.parent.playerid, mark_name]));
            data = data.filter((e) => e !== -1);
            if (data.length === 0)
              return;

            params.ids = data;
          }

          // Just for using room's right drawer
          roomScene.startCheat("../RoomElement/ViewPile", params);
        }
      }
    }
  }

  ColumnLayout {
    id: markTxtList
    x: 2
    spacing: 0
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
    if (mark.startsWith('@$') || mark.startsWith('@&')) {
      special_value += data.length;
      data = data.join(',');
    } else {
      data = data instanceof Array ? data.map((markText) => Backend.translate(markText)).join(' ') : Backend.translate(data);
    }

    if (modelItem) {
      modelItem.special_value = special_value;
      modelItem.mark_extra = data;
    } else {
      markList.append({ mark_name: mark, mark_extra: data, special_value });
    }

    arrangeMarks();
  }

  function removeMark(mark) {
    let i, modelItem;
    for (i = 0; i < markList.count; i++) {
      if (markList.get(i).mark_name === mark) {
        markList.remove(i, 1);
        arrangeMarks();
        return;
      }
    }
  }

  function arrangeMarks() {
    let x = 0;
    let y = 0;
    let i;
    const marks = [];
    const long_marks = [];
    for (i = 0; i < markRepeater.count; i++) {
      const item = markRepeater.itemAt(i);
      const w = item.width;
      if (w < width / 2) marks.push(item);
      else long_marks.push(item);
    }

    marks.concat(long_marks).forEach(item => {
      const w = item.width;
      if (x === 0) {
        item.x = x; item.y = y;

        if (w < width / 2) {
          x += width / 2;
        } else {
          x = 0; y += 22;
        }
      } else {
        if (w < width / 2) {
          item.x = x; item.y = y;
          x = 0; y += 22;
        } else {
          item.x = 0; item.y = y + 22;
          x = 0; y += 44;
        }
      }

      height = x ? y + 22 : y;
    });

    if (i === 0) height = 0;
  }
}
