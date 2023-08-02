// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
  RowLayout {
    anchors.fill: parent
    spacing: 10

    ListView {
      id: listView
      clip: true
      width: parent.width * 0.2
      height: parent.height
      model: ListModel {
        id: modeList
      }
      highlight: Rectangle { color: "lightsteelblue"; radius: 5 }
      delegate: Item {
        width: parent.width
        height: 40

        Text {
          text: name
          anchors.centerIn: parent
        }

        TapHandler {
          onTapped: {
            listView.currentIndex = index;
          }
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: "#88EEEEEE"
      Flickable {
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
          text: Backend.translate(":" + modeList.get(listView.currentIndex).orig_name)
          textFormat: Text.MarkdownText
          font.pixelSize: 16
        }
      }
    }
  }

  Button {
    text: qsTr("Quit")
    anchors.bottom: parent.bottom
    onClicked: {
      mainStack.pop();
    }
  }

  Component.onCompleted: {
    const mode_data = JSON.parse(Backend.callLuaFunction("GetGameModes", []));
    for (let d of mode_data) {
      modeList.append(d);
    }
  }
}
