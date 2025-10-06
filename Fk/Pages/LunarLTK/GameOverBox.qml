// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.qmlmodels

import Fk
import Fk.Components.Common

GraphicsBox {
  property string winner: "tobechanged"
  property string my_role: "" // 拿不到Self.role
  property var summary: []
  property bool summaryShown: true

  id: root
  title.text: victoryResult(winner, my_role, true)
  width: summaryShown ? 780 : 400
  height: queryResultList.height + 96

  TableView {
    id: queryResultList
    anchors.horizontalCenter: parent.horizontalCenter
    // width: parent.width - 30
    // height: parent.height - 30 - body.height - title.height
    width: Math.min(contentWidth, parent.width - 30)
    height: parent.summaryShown ? contentHeight : 0
    y: title.height + 10
    clip: true
    columnSpacing: 10
    pressDelay: 500

    rowHeightProvider: () => 34
    columnWidthProvider: (col) => {
      let w = explicitColumnWidth(column);
      if (w >= 0)
        return Math.max(40, w);
      return implicitColumnWidth(column);
    }

    model: TableModel {
      id: tableModel
      TableModelColumn { display: "general" }
      TableModelColumn { display: "scname" }
      TableModelColumn { display: "win" }
      TableModelColumn { display: "role" }
      TableModelColumn { display: "turn" }
      TableModelColumn { display: "recover" }
      TableModelColumn { display: "damage" }
      TableModelColumn { display: "damaged" }
      TableModelColumn { display: "kill" }
      TableModelColumn { display: "honor" }

      rows: [
        {
          general: `<b>${Lua.tr("General")}</b>`,
          scname: `<b>${Lua.tr("Name")}</b>`,
          win: `<b>${Lua.tr("Victory or Defeat")}</b>`,
          role: `<b>${Lua.tr("Role")}</b>`,
          turn: `<b>${Lua.tr("Turn")}</b>`,
          recover: `<b>${Lua.tr("Recover")}</b>`,
          damage: `<b>${Lua.tr("Damage")}</b>`,
          damaged: `<b>${Lua.tr("Damaged")}</b>`,
          kill: `<b>${Lua.tr("Kill")}</b>`,
          honor: `<b>${Lua.tr("Honor")}</b>`,
        }
      ]
    }

    delegate: Text {
      text: display
      color: "#E4D5A0"
      font.pixelSize: 20
      horizontalAlignment: column === 8 ? Text.AlignLeft : Text.AlignHCenter
    }
  }

  ToolButton {
    text: (parent.summaryShown ? "➖" : "➕")
    onClicked: {
      parent.summaryShown = !parent.summaryShown
    }
    anchors.top: parent.top
    anchors.right: parent.right
  }

  RowLayout {
    id: body
    anchors.right: parent.right
    anchors.rightMargin: parent.summaryShown ? 15 : parent.width / 2 - 15 - bkmBtn.width - repBtn.width / 2
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    width: parent.width
    spacing: 15

    Item { Layout.fillWidth: true }
    MetroButton {
      text: Lua.tr("Back To Room")
      visible: !Config.observing

      onClicked: {
        Mediator.notify(root, Command.ResetRoomPage);
        finished();
      }
    }

    MetroButton {
      text: Lua.tr("Back To Lobby")

      onClicked: {
        Mediator.notify(root, Command.IWantToQuitRoom);
      }
    }

    MetroButton {
      id: repBtn
      text: Lua.tr("Save Replay")
      visible: Config.observing && !Config.replaying // 旁观

      onClicked: {
        repBtn.visible = false;
        Mediator.notify(root, Command.IWantToSaveRecord);
      }
    }

    MetroButton {
      id: bkmBtn
      text: Lua.tr("Bookmark Replay")
      visible: !Config.observing && !Config.replaying // 玩家

      onClicked: {
        bkmBtn.visible = false;
        Mediator.notify(root, Command.IWantToBookmarkRecord);
      }
    }
  }

  function getSummary() {
    const summaryData = Lua.evaluate("ClientInstance.banners['GameSummary']");
    if (!summaryData || summaryData.length === 0) {
      return;
    }
    Lua.call("FindMosts");
    summaryData.forEach((s, index) => {
      let _s = Lua.call("Entitle", s, index, winner);
      _s.turn = s.turn.toString();
      _s.recover = s.recover.toString();
      _s.damage = s.damage.toString();
      _s.damaged = s.damaged.toString();
      _s.kill = s.kill.toString();
      _s.scname = s.scname; // client拿不到
      _s.win = victoryResult(winner, _s.role, true);
      _s.role = Lua.tr(_s.role);
      _s.general = Lua.tr(_s.general);
      if (!_s.general) {
        _s.general = "----";
      }
      if (_s.deputy) {
        _s.general = _s.general + "/" + Lua.tr(_s.deputy);
      }
      // model.append(_s);
      tableModel.appendRow(_s)
    });
  }

  function victoryResult(winner, role, cap) {
    let ret = "";
    if (winner === "") {
      ret = 3; // draw
    } else if (winner.split("+").includes(role)) {
      ret = 1; // win
    } else {
      ret = 2; // lose
    }
    if (cap) {
      return ret === 1 ? Lua.tr("Game Win") :
        (ret === 2 ? Lua.tr("Game Lose") : Lua.tr("Game Draw"));
    } else {
      return ret === 1 ? "win" :
        (ret === 2 ? "lose" : "draw");
    }
  }

  onWinnerChanged: {
    if (!Config.disableGameOverAudio) {
      Backend.playSound("./audio/system/" + victoryResult(winner, my_role, false));
    }

    getSummary();
  }

  Component.onCompleted: {
    my_role = Lua.evaluate("Self.role");
  }
}
