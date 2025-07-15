// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk.Widgets as W

Item {
  id: root
  width: 138
  property var bgColor: "#3C3229"

  ListModel {
    id: markList
  }

  Rectangle {
    anchors.bottom: parent.bottom
    width: parent.width
    height: parent.height
    color: bgColor
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
        text: luatr(mark_name) + ' '
              + (special_value !== '' ? special_value : mark_extra) // @$ @& 直接在名字里显示个数，牌堆是updatePileInfo控制标记值
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

      W.TapHandler {
        enabled: root.parent.state != "candidate" || !root.parent.selectable
        onTapped: {
          const params = { name: mark_name };

          // @& 武将牌
          if (mark_name.startsWith('@&')) {
            params.cardNames = mark_extra.split(',');
            roomScene.startCheat("../RoomElement/ViewGeneralPile", params);
            return;
          }

          // @$ 游戏牌名
          if (mark_name.startsWith('@$')) {
            let data = mark_extra.split(',');
            if (!Object.is(parseInt(data[0]), NaN)) {
              params.ids = data.map(s => parseInt(s));
            } else {
              params.cardNames = data;
            }
          } else if (mark_name.startsWith('@[')) {
            // @[xxx]yyy 怀疑是不是qml标记
            const close_br = mark_name.indexOf(']');
            if (close_br === -1) return;

            const mark_type = mark_name.slice(2, close_br);
            const _data = mark_extra;
            let data = lcall("GetQmlMark", mark_type, mark_name, _data,
                             root.parent?.playerid);
            if (data && data.qml_path) {
              params.data = data.qml_data;
              params.owner = root.parent?.playerid;
              roomScene.startCheatByPath(data.qml_path, params);
            }
            return;
          } else {
            if (!root.parent.playerid) return;
            let data = lcall("GetPile", root.parent.playerid, mark_name);
            data = data.filter((e) => lcall("CardVisibility", e));
            if (data.length === 0)
              return;

            params.ids = data;
          }

          // Just for using right drawer of the room
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
    } else if (mark.startsWith('@[')) {
      const close_br = mark.indexOf(']');
      if (close_br !== -1) {
        const mark_type = mark.slice(2, close_br);
        data = JSON.stringify(data);
        const _data = lcall("GetQmlMark", mark_type, mark, data,
                            root.parent?.playerid);
        if (_data && _data.text) {
          special_value = _data.text;
        }
      }
    } else {
      data = data instanceof Array
           ? data.map((markText) => luatr(markText)).join(' ')
           : luatr(data);
    }

    if (modelItem) { // 如果已经存在
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
