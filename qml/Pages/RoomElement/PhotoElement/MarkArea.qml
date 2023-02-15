import QtQuick
import QtQuick.Layouts

Item {
  id: root
  width: 138
  height: markTxtList.height

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
  }

  ColumnLayout {
    id: markTxtList
    x: 2
    spacing: 0
    Repeater {
      model: markList
      Item {
        width: childrenRect.width
        height: 22
        Text {
          text: Backend.translate(mark_name) + ' ' + Backend.translate(mark_extra)
          font.family: fontLibian.name
          font.pixelSize: 22
          color: "white"
          style: Text.Outline
          textFormat: Text.RichText
        }

        // TODO: for pile
        // MouseArea {
        //   anchors.fill: parent
        // }
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
    if (modelItem)
      modelItem.mark_extra = data;
    else
      markList.append({ mark_name: mark, mark_extra: data });
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
