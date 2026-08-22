// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import Fk.Widgets as W

import LunarLtk
import LunarLtk.Models
import LunarLtk.Components

ColumnLayout {
  id: root
  anchors.fill: parent
  anchors.leftMargin: 16
  anchors.rightMargin: 16
  anchors.topMargin: 8

  signal finish()

  required property PhotoModel dataModel

  RowLayout {
    spacing: 8
    Avatar {
      id: avatar
      Layout.preferredWidth: 56
      Layout.preferredHeight: 56
      general: root.dataModel.avatar
    }

    ColumnLayout {
      Text {
        id: screenName
        font.pixelSize: 18
        color: "#E4D5A0"
        text: {
          const id = dataModel.playerid;
          if (id === 0 || id === undefined) return "";

          let ret = Config.hideScreenName ?
            (root.dataModel.seatNumber ? Lua.tr("seat#" + root.dataModel.seatNumber.toString()) : Lua.tr("Player"))
            : root.dataModel.screenName; // 如果有座位号，显示几号位

          const gamedata = Lua.getPlayerGameData(id);
          const totalTime = gamedata[3];
          const h = (totalTime / 3600).toFixed(2);
          const m = Math.floor(totalTime / 60);
          if (m < 100) {
            ret += " (" + Lua.tr("TotalGameTime: %1 min").arg(m) + ")";
          } else {
            ret += " (" + Lua.tr("TotalGameTime: %1 h").arg(h) + ")";
          }

          return ret;
        }
      }

      Text {
        id: playerGameData
        Layout.fillWidth: true
        font.pixelSize: 18
        color: "#E4D5A0"
        text: {
          const id = dataModel.playerid;
          if (id === 0 || id === undefined) return "";

          const gamedata = Lua.getPlayerGameData(id);
          const total = gamedata[0];
          const win = gamedata[1];
          const run = gamedata[2];
          const winRate = (win / total) * 100;
          const runRate = (run / total) * 100;

          return total === 0 ? Lua.tr("Newbie") :
            Lua.tr("Win=%1 Run=%2 Total=%3").arg(winRate.toFixed(2))
              .arg(runRate.toFixed(2)).arg(total);
        }
      }
    }
  }

  RowLayout {
    MetroButton {
      text: Lua.tr("Give Flower")
      visible: !Config.observing
      onClicked: {
        enabled = false;
        root.givePresent("Flower");
        root.finish();
      }
    }

    MetroButton {
      text: Lua.tr("Give Egg")
      visible: !Config.observing
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
      visible: !Config.observing
      enabled: Math.random() < 0.3
      onClicked: {
        enabled = false;
        root.givePresent("Wine");
        root.finish();
      }
    }

    MetroButton {
      text: Lua.tr("Give Shoe")
      visible: !Config.observing
      enabled: Math.random() < 0.3
      onClicked: {
        enabled = false;
        root.givePresent("Shoe");
        root.finish();
      }
    }

    MetroButton {
      text: {
        const name = dataModel.screenName;
        const blocked = !Config.blockedUsers.includes(name);
        return blocked ? Lua.tr("Block Chatter") : Lua.tr("Unblock Chatter");
      }
      enabled: root.dataModel.playerid !== Cpp.self.id && root.dataModel.playerid > 0 // 旁观屏蔽不了正在被旁观的人
      onClicked: {
        const name = dataModel.screenName;
        const idx = Config.blockedUsers.indexOf(name);
        if (idx === -1) {
          if (name === "") return;
          Config.blockedUsers.push(name);
        } else {
          Config.blockedUsers.splice(idx, 1);
        }
        Config.blockedUsersChanged();
      }
    }

    MetroButton {
      text: Lua.tr("Change Skin")
      visible: !Config.observing && root.dataModel.playerid === Ltk.roomScene.dataModel?.dashboardId
      enabled: !Config.observing && root.dataModel.playerid === Ltk.roomScene.dataModel?.dashboardId && (Ltk.getSkinNamesByGeneral(root.dataModel.general).length > 0 || Ltk.getSkinNamesByGeneral(root.dataModel.deputyGeneral).length > 0 || Cpp.quickStartMode) && !root.dataModel.photoItem.changeSkinTimer.running
      onClicked: {
        // 草了这什么神秘bug，从这不能直接打开infoPopup
        const item = root.dataModel.photoItem.skinIcon
        const timer = root.dataModel.photoItem.changeSkinTimer
        item.clicked()
        timer.start()
      }
    }
  }

  RowLayout {
    spacing: 20
    ColumnLayout {
      Layout.alignment: Qt.AlignTop
      Layout.topMargin: 16

      GeneralCardItem {
        id: mainChara
        dataModel: Ltk.createGeneralCardModel(root.dataModel.general)
        visible: true
      }
      GeneralCardItem {
        id: deputyChara
        dataModel: Ltk.createGeneralCardModel(root.dataModel.deputyGeneral || "caocao")
        visible: !!root.dataModel.deputyGeneral
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      Layout.topMargin: 10

      SwipeView {
        id: detailSwipeView
        Layout.fillWidth: true
        Layout.fillHeight: true
        interactive: false
        currentIndex: drawerBar.currentIndex
        clip: true

        Flickable {
          width: detailSwipeView.width
          height: detailSwipeView.height
          contentHeight: skillDesc.height
          ScrollBar.vertical: ScrollBar {}
          DescriptionText {
            id: skillDesc
            color: "#E4D5A0"
            width: detailSwipeView.width
            text: root.getSkillDescText();
          }
        }

        Flickable {
          width: detailSwipeView.width
          height: detailSwipeView.height
          contentHeight: equipDesc.height
          ScrollBar.vertical: ScrollBar {}
          DescriptionText {
            id: equipDesc
            color: "#E4D5A0"
            width: detailSwipeView.width
            text: root.getCardAreaDescText("e");
          }
        }

        Flickable {
          width: detailSwipeView.width
          height: detailSwipeView.height
          contentHeight: judgeDesc.height
          ScrollBar.vertical: ScrollBar {}
          DescriptionText {
            id: judgeDesc
            color: "#E4D5A0"
            width: detailSwipeView.width
            text: root.getCardAreaDescText("j");
          }
        }

        Flickable {
          width: detailSwipeView.width
          height: detailSwipeView.height
          contentHeight: knownCardsDesc.height
          ScrollBar.vertical: ScrollBar {}
          DescriptionText {
            id: knownCardsDesc
            color: "#E4D5A0"
            width: detailSwipeView.width
            text: root.getKnownCardsDesc();
          }
        }

      }

      W.ViewSwitcher {
        id: drawerBar
        fontColor: "#E4D5A0"
        highlight: Rectangle { color: "#535046"; radius: 8; border.width: 1; border.color: "gray" }
        Layout.alignment: Qt.AlignHCenter
        model: [
          Lua.tr("skill"),
          Lua.tr("$Equip"),
          Lua.tr("$Judge"),
          Lua.tr("$Hand"),
        ]
      }
    }
  }

  function givePresent(p) {
    ClientInstance.notifyServer(
      "Chat",
      {
        type: 2,
        msg: "$@" + p + ":" + dataModel.playerid
      }
    );
  }

  function getSkillDescText() {
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
    let desc = skillnamecss;

    const id = dataModel.playerid;
    if (id === 0 || id === undefined) return;
    const player = Ltk.getPlayer(id);
    const self = Lua.selfPlayer;

    const skills = Ltk.getPlayerSkills(id);
    const skillNames = skills.map(s => s.orig_name);
    skills.forEach(t => {
      // TODO 等core更新强制重启后把这个智慧杀了 GetPlayerSkill直接返回invalid
      const invalid = t.name.endsWith(Lua.tr('skill_invalidity'));
      let skillText = `<font class='${invalid ? "skill-name locked" : "skill-name"}'>${t.name}</font> `;
      if (invalid) {
        skillText += `<font color='grey'>${t.description}</font>`;
      } else {
        skillText += `${t.description}`;
      }

      desc += skillText + "<br/>";

      for (const rs of t.related_skills) {
        if (!skillNames.includes(rs)) {
          desc += (`<font color="pink" class='skill-name'><b>` + Lua.tr(rs) +
          "</b></font> <font color='pink'>" + Lua.evaluate(`Fk:getDescription('${rs}')`) + '</font>')+ "<br/>";
        }
      }
    });
    return desc;

  }

  function getCardAreaDescText(flag) {
    const cardnamecss = `
    <style>
    .card-name {
      color: "#9bdcd5";
      font-size: 20px;
      font-weight: bold;
    }
    </style>
    `;
    let desc = cardnamecss;

    const id = dataModel.playerid;
    if (id === 0 || id === undefined) return;
    const player = Ltk.getPlayer(id);
    const self = Lua.selfPlayer;

    const ej = player.getCardIds(flag);
    let unknownCardsNum = 0;
    ej.forEach(cid => {
      const t = Ltk.getCardData(cid);
      if (self.cardVisible(cid)) {
        const v = player.getVirtualEquip(cid) || Ltk.getCard(cid);
        desc += (
          "<b><font class='card-name'>" + v.toLogString(false)
          + "</font></b> " + v.getDynamicDescription(player)
        ) + "<br/>";
      } else {
        unknownCardsNum++;
      }
    });
    if (unknownCardsNum > 0) {
      desc += ("------------------------------------") + "<br/>";
      desc += (Lua.tr("unknown") + " * " + (unknownCardsNum))+ "<br/>";
    }
    return desc;
  }

  function getKnownCardsDesc() {
    // 幽默记牌器环节 FIXME：帮忙补补翻译表 FIXME: 帮忙补补区域 FIXME: 帮忙整个重做
    const knownHandcards = Lua.ev(`Self.card_tracker:getPlayerKnownCards(${dataModel.playerid}, Player.Hand)`);
    if (!knownHandcards) {
      return ("没有已知手牌");
    } else {
      const realKnown = knownHandcards.known_cards;
      const uncertain = knownHandcards.uncertain_cards;
      if (realKnown.length === 0 && uncertain.length === 0) {
        return ("没有已知手牌");
      } else {
        if (realKnown.length > 0) {
          return ("已知手牌：" +
            realKnown.map(id => Ltk.getCard(id).toLogString(false)).join(","));
        }
        if (uncertain.length > 0) {
          return ("不确定手中是否拥有的手牌：" +
            uncertain.map(id => Ltk.getCard(id).toLogString(false)).join(","));
        }
      }
    }
  }

  Component.onCompleted: {
    skillDesc.clearSavedText();
    equipDesc.clearSavedText();
    judgeDesc.clearSavedText();
  }
}
