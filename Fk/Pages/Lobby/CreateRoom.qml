// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Widgets as W

import LunarLtk

Item {
  id: root
  anchors.fill: parent
  property bool isChangeRoom: false
  property var config: ({})

  signal finish()

  W.SideBarSwitcher {
    id: bar
    width: 200
    height: parent.height
    model: ListModel {
      ListElement { name: "General Settings" }
      ListElement { name: "Game Mode Select" }
      ListElement { name: "Game Settings" }
      ListElement { name: "Mode Settings" }
      ListElement { name: "Package Settings" }
      ListElement { name: "Ban General Settings" }
    }
  }

  SwipeView {
    width: root.width - bar.width - 16
    x: bar.width + 16
    height: root.height - buttonBar.height - 8
    clip: true
    interactive: false
    orientation: Qt.Vertical
    currentIndex: bar.currentIndex
    RoomGeneralSettings {
      id: roomGeneralSettings
      config: root.config
      onSettingsUpdated: {
        boardgameSettings.updateSettingsUI();
        gameModeSettings.updateSettingsUI();
        root.updateFeasible();
      }
    }
    GameModeSelectPage {
      id: gameModeSelectPage
      onGameModeChanged: {
        roomGeneralSettings.refreshGameMode(gameMode);
        const getUIData = Lua.fn("GetUIDataOfSettings");
        const boardgameName = Lua.evaluate(`Fk:getBoardGame('${gameMode}').name`);

        const boardgameConf = Db.getModeSettings(boardgameName);
        const gameModeConf = Db.getModeSettings(boardgameName + ':' + gameMode);
        const config = {
          playerNum: roomGeneralSettings.playerNum,
          timeout: Config.preferredTimeout,
          gameMode,
          _game: boardgameConf,
          _mode: gameModeConf,
        };
        root.config = config;

        let needcopy = false;

        const boardgameSettingsData = getUIData(gameMode, config, true);
        const gameSettingsData = getUIData(gameMode, config, false);
        needcopy = needcopy || !!boardgameSettingsData.find(v => v["_needcopy"])
          || !!gameSettingsData.find(v => v["_needcopy"]);

        boardgameSettings.configName = boardgameName;
        boardgameSettings.gameModeName = gameMode;
        // boardgameSettings.config = config;
        boardgameSettings.needcopy = needcopy;
        boardgameSettings.loadSettingsUI(boardgameSettingsData);

        gameModeSettings.configName = `${boardgameName}:${gameMode}`;
        gameModeSettings.gameModeName = gameMode;
        // gameModeSettings.config = config;
        gameModeSettings.needcopy = needcopy;
        gameModeSettings.loadSettingsUI(gameSettingsData);

        root.updateFeasible();
      }
    }
    LuaSettingsPage {
      id: boardgameSettings
      isBoardgame: true
      config: root.config
      onSettingsUpdated: {
        boardgameSettings.updateSettingsUI();
        gameModeSettings.updateSettingsUI();
        root.updateFeasible();
      }
    }
    LuaSettingsPage {
      id: gameModeSettings
      isBoardgame: false
      config: root.config
      onSettingsUpdated: {
        boardgameSettings.updateSettingsUI();
        gameModeSettings.updateSettingsUI();
        root.updateFeasible();
      }
    }
    Item {
      RoomPackageSettings {
        anchors.fill: parent
      }
    }
    BanGeneralSetting {}
  }

  Rectangle {
    id: buttonBar
    anchors.left: bar.right
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
    height: 56 - 8
    color: "transparent"
    RowLayout {
      width: parent.width * 0.5
      height: parent.height
      anchors.centerIn: parent
      // anchors.rightMargin: 8
      spacing: 16
      W.ButtonContent {
        id: okButton
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        text: Lua.tr("OK")
        onClicked: {
          Config.saveConf();
          root.finish();
          App.setBusy(true);
          let k, arr;

          let disabledGenerals = [];
          for (k in Config.curScheme.banPkg) {
            arr = Config.curScheme.banPkg[k];
            if (arr.length !== 0) {
              const generals = Ltk.getGenerals(k);
              if (generals.length !== 0) {
                disabledGenerals.push(...generals.filter(g => !arr.includes(g)));
              }
            }
          }
          for (k in Config.curScheme.normalPkg) {
            arr = Config.curScheme.normalPkg[k] ?? [];
            if (arr.length !== 0)
            disabledGenerals.push(...arr);
          }

          let disabledPack = Config.curScheme.banCardPkg.slice();
          for (k in Config.curScheme.banPkg) {
            if (Config.curScheme.banPkg[k].length === 0)
            disabledPack.push(k);
          }
          Config.serverHiddenPacks.forEach(p => {
            if (!disabledPack.includes(p)) {
              disabledPack.push(p);
            }
          });

          const gameMode = Config.preferedMode;
          const boardgameName = Lua.evaluate(`Fk:getBoardGame('${gameMode}').name`);
          const boardgameConf = Db.getModeSettings(boardgameName);
          const gameModeConf = Db.getModeSettings(boardgameName + ":" + gameMode);

          ClientInstance.notifyServer(root.isChangeRoom ? "ChangeRoom" : "CreateRoom", [
            roomGeneralSettings.roomName, roomGeneralSettings.playerNum,
            Config.preferredTimeout, {
              gameMode,
              roomName: roomGeneralSettings.roomName,
              password: roomGeneralSettings.roomPassword,
              _game: boardgameConf,
              _mode: gameModeConf,
              // FIXME 暂且拿他俩没办法
              disabledPack: boardgameName === "lunarltk" ? disabledPack : [],
              disabledGenerals: boardgameName === "lunarltk" ? disabledGenerals : [],
            }
          ]);
        }
      }

      W.ButtonContent {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        text: Lua.tr("Cancel")
        onClicked: {
          root.finish();
        }
      }
    }
  }

  function updateFeasible() {
    okButton.enabled = !!Lua.fn(`function(modeName, settings)
      local mode = Fk.game_modes[modeName]
      return mode and mode:feasible(settings)
    end`)(gameModeSelectPage.gameMode, boardgameSettings.config)
  }
}
