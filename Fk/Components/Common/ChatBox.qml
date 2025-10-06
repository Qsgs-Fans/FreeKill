// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk

Rectangle {
  color: "transparent"
  property bool isLobby: false

  function append(chatter) {
    chatLogBox.append({ logText: chatter })
  }

  function loadSkills() {
    for (let i = 1; i <= 23; i++) {
      skills.append({ name: "fastchat_m", idx: i });
    }
  }

  Timer {
    id: opTimer
    interval: 1500
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
      model: 59
      visible: false
      clip: true
      delegate: ItemDelegate {
        Image {
          height: 32; width: 32
          anchors.centerIn: parent
          source: AppPath + "/image/emoji/" + index
        }
        onClicked: chatEdit.insert(chatEdit.cursorPosition,
                                   "{emoji" + index + "}");
      }
    }

    ListView {
      id: soundSelector
      Layout.fillWidth: true
      Layout.preferredHeight: 180
      visible: false
      clip: true
      ScrollBar.vertical: ScrollBar {}
      model: ListModel {
        id: skills
      }
      // onVisibleChanged: {skills.clear(); loadSkills();}

      delegate: ItemDelegate {
        width: soundSelector.width
        height: 30
        text: Lua.tr("$" + name + (idx ? idx.toString() : ""))

        onClicked: {
          opTimer.start();
          const general = roomScene.getPhoto(Self.id).general;
          let skill = "fastchat_m";
          if (general !== "") {
            const data = Lua.call("GetGeneralDetail", general);
            const gender = data.gender;
            if (gender !== 1) {
              skill = "fastchat_f";
            }
          }
          ClientInstance.notifyServer(
            "Chat",
            {
              type: isLobby ? 1 : 2,
              msg: "$" + skill + ":" + idx
            }
          );
          soundSelector.visible = false;
        }
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
          maximumLength: 300

          onAccepted: {
            if (text != "") {
              ClientInstance.notifyServer(
                "Chat",
                {
                  type: isLobby ? 1 : 2,
                  msg: text
                }
              );
              text = "";
            }
          }
        }
      }

      MetroButton {
        id: soundBtn
        text: "🗨️"
        visible: !isLobby
        enabled: !opTimer.running;
        onClicked: {
          emojiSelector.visible = false;
          soundSelector.visible = !soundSelector.visible;
        }
      }

      MetroButton {
        id: emojiBtn
        text: "😃"
        onClicked: {
          soundSelector.visible = false;
          emojiSelector.visible = !emojiSelector.visible;
        }
      }

      MetroButton {
        text: "✔️"
        enabled: !opTimer.running;
        onClicked: {
          opTimer.start();
          chatEdit.accepted();
        }
      }
    }
  }

  Component.onCompleted: {
    loadSkills();
  }
}
