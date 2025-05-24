// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.qmlmodels
import Fk.Pages
import Fk.Common

GraphicsBox {
  property string winner: "tobechanged"
  property string my_role: "" // 拿不到Self.role
  property var summary: []
  property bool summaryShown: true

  id: root
  title.text: winner !== "" ? (winner.split("+").indexOf(my_role)=== -1 ?
                              luatr("Game Lose") : luatr("Game Win"))
                            : luatr("Game Draw")
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
      TableModelColumn { display: "role" }
      TableModelColumn { display: "turn" }
      TableModelColumn { display: "recover" }
      TableModelColumn { display: "damage" }
      TableModelColumn { display: "damaged" }
      TableModelColumn { display: "kill" }
      TableModelColumn { display: "honor" }

      rows: [
        {
          general: `<b>${luatr("General")}</b>`,
          scname: `<b>${luatr("Name")}</b>`,
          role: `<b>${luatr("Role")}</b>`,
          turn: `<b>${luatr("Turn")}</b>`,
          recover: `<b>${luatr("Recover")}</b>`,
          damage: `<b>${luatr("Damage")}</b>`,
          damaged: `<b>${luatr("Damaged")}</b>`,
          kill: `<b>${luatr("Kill")}</b>`,
          honor: `<b>${luatr("Honor")}</b>`,
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
      text: luatr("Back To Room")
      visible: !config.observing

      onClicked: {
        roomScene.resetToInit();
        finished();
      }
    }

    MetroButton {
      text: luatr("Back To Lobby")

      onClicked: {
        if (config.replaying) {
          mainStack.pop();
          Backend.controlReplayer("shutdown");
        } else {
          ClientInstance.notifyServer("QuitRoom", "[]");
        }
      }
    }

    MetroButton {
      id: repBtn
      text: luatr("Save Replay")
      visible: config.observing && !config.replaying // 旁观

      onClicked: {
        repBtn.visible = false;
        lcall("SaveRecord");
        toast.show("OK.");
      }
    }

    MetroButton {
      id: bkmBtn
      text: luatr("Bookmark Replay")
      visible: !config.observing && !config.replaying // 玩家

      onClicked: {
        bkmBtn.visible = false;
        Backend.saveBlobRecordToFile(ClientInstance.getMyGameData()[0].id); // 建立在自动保存录像基础上
        toast.show("OK.");
      }
    }
  }

  function getSummary() {
    const summaryData = leval("ClientInstance.banners['GameSummary']");
    if (!summaryData || summaryData.length === 0) {
      return;
    }
    lcall("FindMosts");
    summaryData.forEach((s, index) => {
      let _s = lcall("Entitle", s, index, winner);
      _s.turn = s.turn.toString();
      _s.recover = s.recover.toString();
      _s.damage = s.damage.toString();
      _s.damaged = s.damaged.toString();
      _s.kill = s.kill.toString();
      _s.scname = s.scname; // client拿不到
      _s.role = luatr(_s.role);
      _s.general = luatr(_s.general);
      if (!_s.general) {
        _s.general = "----";
      }
      if (_s.deputy) {
        _s.general = _s.general + "/" + luatr(_s.deputy);
      }
      // model.append(_s);
      tableModel.appendRow(_s)
    });
  }

  onWinnerChanged: {
    let sound;
    if (winner === "") {
      sound = "draw";
    } else {
      let splited = winner.split("+");
      if (splited.includes(my_role)) {
        sound = "win";
      } else {
        sound = "lose";
      }
    }
    Backend.playSound("./audio/system/" + sound);
    getSummary();
  }

  Component.onCompleted: {
    my_role = leval("Self.role");
  }
}
