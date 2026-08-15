import QtQuick
import Qt.labs.qmlmodels

import LunarLtk
import Fk

QtObject {
  id: root

  property string winner: ""
  property string myId: ""

  readonly property string titleText: victoryResult(winner, true)

  readonly property bool canContinue:
    !Config.observing && !Config.replaying && Config.roomCapacity === 1

  readonly property bool canBackToRoom: true // !Config.observing
  readonly property bool canSaveReplay: Config.observing && !Config.replaying
  readonly property bool canBookmarkReplay: !Config.observing && !Config.replaying

  property TableModel tableModel: TableModel {
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
        honor: `<b>${Lua.tr("Honor")}</b>`
      }
    ]
  }

  signal finished()
  signal summaryReady()

  function victoryResult(winner, cap) {
    let ret = 3;
    if (winner !== "") {
      ret = winner.split("+").includes(myId)? 1: 2;
    }

    if (cap) {
      return ret === 1 ? Lua.tr("Game Win")
           : ret === 2 ? Lua.tr("Game Lose")
           : Lua.tr("Game Draw");
    }

    return ret === 1 ? "win"
         : ret === 2 ? "lose"
         : "draw";
  }

  function loadSummary() {
    const summaryData = Lua.client.getBanner("GameSummary");
    if (!summaryData || summaryData.length === 0)
      return;

    Ltk.findMosts();

    summaryData.forEach((s, index) => {
      let _s = Ltk.entitle(s, index, winner);

      _s.turn = s.turn.toString();
      _s.recover = s.recover.toString();
      _s.damage = s.damage.toString();
      _s.damaged = s.damaged.toString();
      _s.kill = s.kill.toString();

      _s.scname = s.scname;
      _s.win = Lua.tr(s.win);
      _s.role = Lua.tr(_s.role);
      _s.general = Lua.tr(_s.general) || "----";

      if (_s.deputy)
        _s.general += "/" + Lua.tr(_s.deputy);

      tableModel.appendRow(_s);
    });

    summaryReady();
  }

  function continueGame(view) {
    Mediator.notify(view, Command.ContinueGame);
    finished();
  }

  function backToRoom(view) {
    Mediator.notify(view, Command.ResetRoomPage);
    finished();
  }

  function backToLobby(view) {
    Mediator.notify(view, Command.IWantToQuitRoom);
  }

  function saveReplay(view) {
    Mediator.notify(view, Command.IWantToSaveRecord);
  }

  function bookmarkReplay(view) {
    Mediator.notify(view, Command.IWantToBookmarkRecord);
  }

  onWinnerChanged: {
    if (!Config.disableGameOverAudio) {
      Backend.playSound("./audio/system/" +
        victoryResult(winner, false));
    }

    loadSummary();
  }

  Component.onCompleted: {
    myId = Lua.selfPlayer.id.toString();
  }
}
