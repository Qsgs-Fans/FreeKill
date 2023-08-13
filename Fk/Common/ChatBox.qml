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

  /*
  function loadSkills(pid) {
    if (isLobby) return;
    let gender = 0;
    // let g = false;
    // if (g) {
    //   const data = JSON.parse(Backend.callLuaFunction("GetGeneralDetail", [g]));
    //   const extension  = data.extension;
    //   gender = data.gender;
    //   data.skill.forEach(t => {
    //     for (let i = 0; i < 999; i++) {
    //       const fname = AppPath + "/packages/" + extension + "/audio/skill/" +
    //         t.name + (i !== 0 ? i.toString() : "") + ".mp3";

    //       if (Backend.exists(fname)) {
    //         skills.append({ name: t.name, idx: i });
    //       } else {
    //         if (i > 0) break;
    //       }
    //     }
    //   });
    //   data.related_skill.forEach(t => {
    //     for (let i = 0; i < 999; i++) {
    //       const fname = AppPath + "/packages/" + extension + "/audio/skill/" +
    //         t.name + (i !== 0 ? i.toString() : "") + ".mp3";

    //       if (Backend.exists(fname)) {
    //         skills.append({ name: t.name, idx: i });
    //       } else {
    //         if (i > 0) break;
    //       }
    //     }
    //   });
    // }
    for (let i = 0; i < 999; i++) {
      const name = "fastchat_" + (gender == 1 ? "f" : "m")
      const fname = AppPath + "/packages/standard/audio/skill/" +
        name + (i !== 0 ? i.toString() : "") + ".mp3";

      if (Backend.exists(fname)) {
        skills.append({ name: name, idx: i });
      } else {
        if (i > 0) break;
      }
    }
  }
  */
  function loadSkills() {
    for (let i = 1; i <= 16; i++) {
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
          source: "../../image/emoji/" + index
        }
        onClicked: chatEdit.insert(chatEdit.cursorPosition, "{emoji" + index + "}");
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
        text: Backend.translate("$" + name + (idx ? idx.toString() : ""))

        onClicked: {
          opTimer.start();
          const general = roomScene.getPhoto(Self.id).general;
          let skill = "fastchat_m";
          if (general !== "") {
            const data = JSON.parse(Backend.callLuaFunction("GetGeneralDetail", [general]));
            const gender = data.gender;
            if (gender !== 1) {
              skill = "fastchat_f";
            }
          }
          ClientInstance.notifyServer(
            "Chat",
            JSON.stringify({
              type: isLobby ? 1 : 2,
              msg: "$" + skill + ":" + idx
            })
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
