// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import Fk.Components.LunarLTK

Flickable {
  id: root
  anchors.fill: parent
  property var extra_data: ({})
  property int pid
  property bool isObserving: false // 指该角色是否为旁观者

  signal finish()

  contentHeight: details.height
  ScrollBar.vertical: ScrollBar {}

  ColumnLayout {
    id: details
    width: parent.width - 40
    x: 20

    RowLayout {
      spacing: 8
      Avatar {
        id: avatar
        Layout.preferredWidth: 56
        Layout.preferredHeight: 56
        general: "diaochan"
      }

      ColumnLayout {
        Text {
          id: screenName
          font.pixelSize: 18
          color: "#E4D5A0"
        }

        Text {
          id: playerGameData
          Layout.fillWidth: true
          font.pixelSize: 18
          color: "#E4D5A0"
        }
      }
    }

    RowLayout {
      MetroButton {
        text: Lua.tr("Give Flower")
        visible: !Config.observing && !isObserving
        onClicked: {
          enabled = false;
          root.givePresent("Flower");
          root.finish();
        }
      }

      MetroButton {
        text: Lua.tr("Give Egg")
        visible: !Config.observing && !isObserving
        onClicked: {
          enabled = false;
          if (Math.random() < 0.03) {
            root.givePresent("GiantEgg");
          } else {
            root.givePresent("Egg");
          }
          root.finish();
        }
      }

      MetroButton {
        text: Lua.tr("Give Wine")
        visible: !Config.observing && !isObserving
        enabled: Math.random() < 0.3
        onClicked: {
          enabled = false;
          root.givePresent("Wine");
          root.finish();
        }
      }

      MetroButton {
        text: Lua.tr("Give Shoe")
        visible: !Config.observing && !isObserving
        enabled: Math.random() < 0.3
        onClicked: {
          enabled = false;
          root.givePresent("Shoe");
          root.finish();
        }
      }

      MetroButton {
        text: {
          const name = extra_data?.photo ? extra_data.photo.screenName : extra_data.screenName;
          const blocked = !Config.blockedUsers.includes(name);
          return blocked ? Lua.tr("Block Chatter") : Lua.tr("Unblock Chatter");
        }
        enabled: pid !== Self.id && pid > 0 // 旁观屏蔽不了正在被旁观的人
        onClicked: {
          const name = extra_data?.photo ? extra_data.photo.screenName : extra_data.screenName;
          const idx = Config.blockedUsers.indexOf(name);
          if (idx === -1) {
            if (name === "") return;
            Config.blockedUsers.push(name);
          } else {
            Config.blockedUsers.splice(idx, 1);
          }
          Config.blockedUsers = Config.blockedUsers;
        }
      }

      /*
      MetroButton {
        text: Lua.tr("Change Skin")
        visible: pid === Self.id && !root.isObserving
        enabled: !(extra_data?.photo.changeSkinTimer.running)
        onClicked: {
          const photo = extra_data?.photo
          if (photo) {
            roomScene.startCheat("SkinsDetail", {
              skins: getSkinsByName(photo.general),
              deputy_skins: getSkinsByName(photo.deputyGeneral),
              orig_general: photo.general,
              orig_deputy: photo.deputyGeneral,
            });
          }
        }
        function getSkinsByName(general) {
          let arr = Lua.evaluate(`(function()
            return Fk:getSkinsByGeneral("${general}") or {}
          end)()`);
          return arr
        }
      }
      */

      /*
      MetroButton {
        text: Lua.tr("Kick From Room")
        visible: !roomScene.isStarted && roomScene.isOwner
        enabled: {
          if (pid === Self.id) return false;
          if (pid < -1) {
            const { minComp, curComp } = Lua.call("GetCompNum");
            return curComp > minComp;
          }
          return true;
        }
        onClicked: {
          // 傻逼qml喜欢加1.0
          ClientInstance.notifyServer("KickPlayer", Math.floor(pid));
          root.finish();
        }
      }
      */
    }

    RowLayout {
      spacing: 20
      ColumnLayout {
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 16

        GeneralCardItem {
          id: mainChara
          name: "caocao"
          visible: name !== ""
        }
        GeneralCardItem {
          id: deputyChara
          name: "caocao"
          visible: name !== ""
        }
      }

      TextEdit {
        id: skillDesc

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 10
        font.pixelSize: 18
        color: "#E4D5A0"

        readOnly: true
        selectByKeyboard: true
        selectByMouse: false
        wrapMode: TextEdit.WordWrap
        textFormat: TextEdit.RichText
        property var savedtext: []
        function clearSavedText() {
          savedtext = [];
        }
        onLinkActivated: (link) => {
          if (link === "back") {
            text = savedtext.pop();
          } else {
            savedtext.push(text);
            text = '<a href="back">' + Lua.tr("Click to back") + '</a><br>' + Lua.tr(link);
          }
        }
      }
    }
  }

  function givePresent(p) {
    ClientInstance.notifyServer(
      "Chat",
      {
        type: 2,
        msg: "$@" + p + ":" + pid
      }
    );
  }

  onExtra_dataChanged: {
    //if (!extra_data.photo) return;
    const hasPhoto = !!extra_data.photo;
    screenName.text = "";
    playerGameData.text = "";
    const skillnamecss = `
    <style>
    .skill-name {
      color: "#9FD49C";
      font-size: 20px;
      font-weight: bold;
    }
    .skill-name.locked {
      color: "grey";
    }
    </style>
    `;
    skillDesc.text = "";
    skillDesc.clearSavedText();


    const id = hasPhoto? extra_data.photo.playerid : extra_data.id;
    if (id === 0 || id === undefined) return;
    root.pid = id;
    root.isObserving = !hasPhoto && !!extra_data.observing;

    avatar.general = hasPhoto? extra_data.photo.avatar : extra_data.avatar;
    screenName.text = hasPhoto? extra_data.photo.screenName : extra_data.screenName;
    mainChara.name = hasPhoto? extra_data.photo.general : extra_data.general;
    deputyChara.name = hasPhoto? extra_data.photo.deputyGeneral : extra_data.deputyGeneral; // 判空…

    if (!Config.observing) {
      const gamedata = Lua.call("GetPlayerGameData", id);
      const total = gamedata[0];
      const win = gamedata[1];
      const run = gamedata[2];
      const totalTime = gamedata[3];
      const winRate = (win / total) * 100;
      const runRate = (run / total) * 100;
      playerGameData.text = total === 0 ? Lua.tr("Newbie") :
        Lua.tr("Win=%1 Run=%2 Total=%3").arg(winRate.toFixed(2))
        .arg(runRate.toFixed(2)).arg(total);

      const h = (totalTime / 3600).toFixed(2);
      const m = Math.floor(totalTime / 60);
      if (m < 100) {
        screenName.text += " (" + Lua.tr("TotalGameTime: %1 min").arg(m) + ")";
      } else {
        screenName.text += " (" + Lua.tr("TotalGameTime: %1 h").arg(h) + ")";
      }
    }

    if (!root.isObserving) {
      Lua.call("GetPlayerSkills", id).forEach(t => {
        // TODO 等core更新强制重启后把这个智慧杀了 GetPlayerSkill直接返回invalid
        const invalid = t.name.endsWith(Lua.tr('skill_invalidity'));
        let skillText = `${skillnamecss}<font class='${invalid ? "skill-name locked" : "skill-name"}'>${t.name}</font> `;
        if (invalid) {
          skillText += `<font color='grey'>${t.description}</font>`;
        } else {
          skillText += `${t.description}`;
        }

        skillDesc.append(skillText);
      });

      var ej = Lua.call("GetPlayerEquips", id).concat(Lua.call("GetPlayerJudges", id));
      let unknownCardsNum = 0;
      ej.forEach(cid => {
        const t = Lua.call("GetCardData", cid);
        if (Lua.call("CardVisibility", cid)) {
          skillDesc.append("------------------------------------")
          const v = Lua.call("GetVirtualEquipData", id, cid);
          if (v) {
            skillDesc.append(
              "<b>" + "(" + Lua.tr(t.name) + Lua.tr("log_" + t.suit) + Lua.tr(t.number.toString()) + ")" 
              + Lua.tr(v.name) + "</b>: " + Lua.tr(":" + v.name)
            );
          } else {
            skillDesc.append("<b>" + Lua.tr(t.name) + "</b>: " + Lua.tr(":" + t.name));
          }
        } else {
          unknownCardsNum++;
        }
      });
      if (unknownCardsNum > 0) {
        skillDesc.append("------------------------------------")
        skillDesc.append(Lua.tr("unknown") + " * " + (unknownCardsNum));
      }
    }
  }
}
