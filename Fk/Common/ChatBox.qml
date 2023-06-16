// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Fk.Pages

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

    GridView {
      id: emojiSelector
      Layout.fillWidth: true
      Layout.preferredHeight: 120
      cellHeight: 48
      cellWidth: 48
      model: 50
      visible: false
      clip: true
      delegate: ItemDelegate {
        Image {
          height: 32; width: 32
          anchors.centerIn: parent
          source: "../../image/emoji/" + index
        }
        onClicked: chatEdit.insert(chatEdit.cursorPosition, "{emoji" + index + "}");
      }
    }

    RowLayout {
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        color: "#040403"
        radius: 3
        border.width: 1
        border.color: "#A6967A"

        TextInput {
          id: chatEdit
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

      MetroButton {
        id: emojiBtn
        text: "😃"
        onClicked: emojiSelector.visible = !emojiSelector.visible;
      }

      MetroButton {
        text: "✔️"
        onClicked: chatEdit.accepted();
      }
    }
  }
}
