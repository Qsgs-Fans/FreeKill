// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk.Widgets as W

Item {
  objectName: "ModesOverview"
  RowLayout {
    anchors.fill: parent
    spacing: 10

    Rectangle {
      color: "#88EEEEEE"
      radius: 6
      width: parent.width * 0.2
      height: parent.height

      ListView {
        id: listView
        clip: true
        //width: parent.width * 0.2
        //height: parent.height
        anchors.fill:parent
        model: ListModel {
          id: modeList
        }
        highlight: Rectangle { color: "#E91E63"; radius: 5 }
        delegate: Item {
          width: parent.width
          height: 40

          Text {
            text: name
            anchors.centerIn: parent
          }

          W.TapHandler {
            onTapped: {
              listView.currentIndex = index;
              detailFlickable.contentY = 0; // 重置滚动条
            }
          }
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: "#88EEEEEE"
      Flickable {
        id: detailFlickable
        width: parent.width - 16
        height: parent.height - 16
        anchors.centerIn: parent
        contentHeight: modeDesc.height
        ScrollBar.vertical: ScrollBar {}
        clip: true

        Text {
          id: modeDesc
          width: parent.width - 16
          wrapMode: Text.WordWrap
          text: luatr(":" + modeList.get(listView.currentIndex).orig_name)
          textFormat: Text.MarkdownText
          font.pixelSize: 16
        }
      }
    }
  }

  Button {
    text: luatr("Quit")
    anchors.bottom: parent.bottom
    visible: mainStack.currentItem.objectName === "ModesOverview"
    onClicked: {
      mainStack.pop();
    }
  }

  Component.onCompleted: {
    const mode_data = lcall("GetGameModes");
    for (let d of mode_data) {
      modeList.append(d);
    }
    listView.currentIndex = 0;
  }
}
