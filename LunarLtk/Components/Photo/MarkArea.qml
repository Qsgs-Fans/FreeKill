// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Widgets as W

Item {
  id: root

  required property var markModel

  width: 103
  property var bgColor: "#3C3229"
  readonly property int rowHeight: 16

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
    model: root.markModel
    onItemAdded: root.arrangeMarks();
    onItemRemoved: root.arrangeMarks();

    Item {
      id: markItem
      required property var modelData
      width: childrenRect.width
      height: textItem.implicitHeight
      Text {
        id: textItem
        text: {
          const data = markItem.modelData;
          if (!data) return "";
          return `${data.name} ${data.value}`.trim();
        }
        font.family: Config.libianName
        font.pixelSize: 16
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
        onTapped: {
          const spec = markItem.modelData.qml;
          if (spec) {
            const component = Lua.createComponent(spec);
            const prop = spec.prop ?? {};

            if (spec.model) {
              prop.dataModel = createQmlObject(spec.model);
            }
            roomScene.showInfoPopup(component, prop);
          }
        }
      }
    }
  }

  function arrangeMarks() {
    let x = 0;
    let y = 0;
    let i;
    const marks = [];
    const long_marks = [];
    for (i = 0; i < markModel.length; i++) {
      const item = markRepeater.itemAt(i);
      if (item) {
        const w = item.width;
        if (w < width / 2) marks.push(item);
        else long_marks.push(item);
      }
    }

    marks.concat(long_marks).forEach(item => {
      const w = item.width;
      const h = item.height;
      if (x === 0) {
        item.x = x; item.y = y;

        if (w < width / 2) {
          x += width / 2;
        } else {
          x = 0; y += h;
        }
      } else {
        if (w < width / 2) {
          item.x = x; item.y = y;
          x = 0; y += h;
        } else {
          item.x = 0; item.y = y + h;
          x = 0; y += h * 2;
        }
      }

      height = x ? y + h : y;
    });

    if (i === 0) height = 0;
  }
}
