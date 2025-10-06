// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk.Widgets as W
import Fk

Rectangle {
  color: "transparent"
  property bool isLobby: false

  function append(chatter, data) {
    let general = data.general;
    let avatar;
    if (general == "__server") {
      general = "";
      avatar = "__server"
    } else if (Lua.evaluate(`ClientInstance:getPlayerById(${data.sender}) == nil`)) {
      avatar = "__observer";
    }
    chatLogBox.append({
      avatar: avatar || data.general || "unknown",
      general: general,
      msg: data.msg,
      userName: data.userName,
      time: data.time,
      isSelf: data.sender === Self.id,
    })
  }

  function clear() {
    chatLogBox.clear();
  }

  function loadGeneralSkillAudios(general) {
    if (general === "") return;
    const sks = Lua.call("GetGeneralDetail", general).skill;
    sks.forEach(t => {
      if (!t.name.startsWith('#')) {
        //generalText.append((t.is_related_skill ? "<font color=\"purple\"><b>" : "<b>") + Lua.tr(t.name) +
        //"</b>: " + t.description + (t.is_related_skill ? "</font>" : ""));

        const gdata = Lua.call("GetGeneralData", general);
        const extension = gdata.extension;
        let ret = false;
        for (let i = 0; i < 999; i++) {
          const fname = SkinBank.getAudioRealPath(t.name + "_" + general + (i !== 0 ? i.toString() : ""), extension, "skill");

          if (fname !== undefined) {
            ret = true;
            skills.append({ name: t.name, idx: i, specific: true, general: general });
          } else {
            if (i > 0) break;
          }
        }
        if (!ret) {
          const skilldata = Lua.call("GetSkillData", t.name);
          if (!skilldata) return;
          const extension = skilldata.extension;
          for (let i = 0; i < 999; i++) {
            const fname = SkinBank.getAudioRealPath(t.name+ (i !== 0 ? i.toString() : ""), extension, "skill");

            if (fname !== undefined) {
              skills.append({ name: t.name, idx: i, specific: false, general: general});
            } else {
              if (i > 0) break;
            }
          }
        }
      }
    });
  }

  function findWinDeathAudio(general, isWin) {
    if (general === "") return;
    const extension = Lua.call("GetGeneralData", general).extension;
    const fname = SkinBank.getAudioRealPath(general, extension, isWin ? "win" : "death");
    if (Backend.exists(fname)) {
      skills.append({ name: (isWin ? "!" : "~") + general });
    }
  }

  function loadSkills() {
    skills.clear();
    const general = Lua.evaluate(`Self.general`);
    if (general) {
      loadGeneralSkillAudios(general);
      findWinDeathAudio(general, true);
      findWinDeathAudio(general, false);
    }
    const deputyGeneral = Lua.evaluate(`Self.deputyGeneral`);
    if (deputyGeneral) {
      loadGeneralSkillAudios(deputyGeneral);
      findWinDeathAudio(deputyGeneral, true);
      findWinDeathAudio(deputyGeneral, false);
    }
    for (let i = 1; i <= 23; i++) {
      skills.append({ name: "fastchat_m", idx: i, specific: false });
    }
  }

  Timer {
    id: opTimer
    interval: 1500
  }

  Component {
    id: avatarDelegate
    Item {
      width: chatLogBox.width
      height: childrenRect.height
      Avatar {
        id: avatarPic
        width: 36
        height: 36
        general: avatar
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.left: isSelf ? undefined : parent.left
        anchors.right: !isSelf ? undefined : parent.right
      }

      Text {
        id: unameLbl
        anchors.left: isSelf ? undefined : avatarPic.right
        anchors.right: !isSelf ? undefined : avatarPic.left
        anchors.margins: 6
        font.pixelSize: 14
        text: userName + (general ? (" (" + Lua.tr(general) + ")") : "")
          + ' <font color="grey">[' + time + "]</font>"
      }

      Rectangle {
        anchors.left: isSelf ? undefined : avatarPic.right
        anchors.right: !isSelf ? undefined : avatarPic.left
        anchors.margins: 4
        anchors.top: unameLbl.bottom
        width: Math.min(parent.width - 80, childrenRect.width + 12)
        height: childrenRect.height + 12
        radius: 8
        color: isSelf ? "lightgreen" : "lightsteelblue"
        Text {
          width: Math.min(contentWidth, parent.parent.width - 80 - 12)
          x: 6; y: 6
          text: msg
          wrapMode: Text.WrapAnywhere
          font.family: Config.libianName
          font.pixelSize: 16
        }
      }

      W.TapHandler {
        onTapped: chatLogBox.currentIndex = index;
      }
    }
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
        delegate: avatarDelegate
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
      property int soundIdx: 0

      onVisibleChanged: {
        if (soundSelector.visible) {
          loadSkills();
          soundSelector.contentY = soundIdx; // restore the last position
        } else {
          soundIdx = soundSelector.contentY;
          skills.clear();
        }
      }

      delegate: ItemDelegate {
        width: soundSelector.width
        height: 30
        text: {
          const isWinOrDeathAudio = name.startsWith("~") || name.startsWith("!");
          let ret = name;

          if (!isWinOrDeathAudio) {
            ret = `$${name}${specific ? '_' + general : ""}${idx ? idx.toString() : ""}`;
          }

          return Lua.tr(ret);
        }

        onClicked: {
          opTimer.start();
          const general = Lua.evaluate(`Self.general`);
          if ( name === "fastchat_m" ) {
            if (general !== "") {
              const data = Lua.call("GetGeneralDetail", general);
              const gender = data.gender;
              if (gender !== 1) {
                name = "fastchat_f";
              }
            }
          }
          ClientInstance.notifyServer(
            "Chat",
            {
              type: isLobby ? 1 : 2,
              msg: (name.startsWith("~") || name.startsWith("!")) ?
                "$" + name :
                "$" + name + ":" + (idx ? idx.toString() : "") + (specific ? ":" + general : "")
            }
          );
          soundSelector.visible = false;
        }
      }
    }

    RowLayout {
      TextField {
        id: chatEdit
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        // color: "#040403"
        // radius: 3
        // border.width: 1
        // border.color: "#A6967A"

        // color: "white"
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

