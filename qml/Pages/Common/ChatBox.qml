// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

Rectangle {
  property bool isLobby: false

  function append(chatter) {
    chatLogBox.append(chatter)
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      LogEdit {
        id: chatLogBox
        anchors.fill: parent
        anchors.margins: 10
        //font.pixelSize: 14
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 28
      color: "#040403"
      radius: 3
      border.width: 1
      border.color: "#A6967A"

      TextInput {
        anchors.fill: parent
        anchors.margins: 6
        color: "white"
        clip: true
        font.pixelSize: 14

        onAccepted: {
          if (text != "") {
            ClientInstance.notifyServer(
              "Chat",
              JSON.stringify({
                type: isLobby ? 1 : 2,
                msg: text
              })
            );
            text = "";
          }
        }
      }
    }
  }
}
