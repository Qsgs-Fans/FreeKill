// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Widgets as W

import LunarLtk

Item {
  id: root

  width: 600
  height: 800

  required property var config

  readonly property alias roomName: roomName.text
  readonly property alias playerNum: playerNum.value
  readonly property alias roomPassword: roomPassword.text

  signal settingsUpdated()

  W.PreferencePage {
    id: prefPage
    anchors.fill: parent
    groupWidth: width * 0.8
    W.PreferenceGroup {
      title: Lua.tr("Basic settings")
      W.EntryRow {
        id: roomName
        title: Lua.tr("Room Name")
        text: Lua.tr("$RoomName").arg(Config.hideScreenName ? Lua.tr("Player") : Self.screenName)
      }
    }

    W.PreferenceGroup {
      W.EntryRow {
        id: roomPassword
        title: Lua.tr("Room Password")
      }
    }

    W.PreferenceGroup {
      title: Lua.tr("Properties")
      W.SpinRow {
        id: playerNum
        title: Lua.tr("Player num")
        from: 1
        to: 10
        value: Config.preferedPlayerNum

        onValueChanged: {
          Config.preferedPlayerNum = value;
          root.config.playerNum = value;
          root.settingsUpdated();
        }
      }
      W.SpinRow {
        title: Lua.tr("Operation timeout")
        from: 10
        to: 60
        editable: true
        value: Config.preferredTimeout

        onValueChanged: {
          Config.preferredTimeout = value;
          root.config.timeout = value;
          root.settingsUpdated();
        }
      }
    }

    Component.onCompleted: {
      playerNum.value = Config.preferedPlayerNum;

      for (let k in Config.curScheme.banPkg) {
        Ltk.updatePackageEnable(k, false);
      }
      Config.curScheme.banCardPkg.forEach(p => Ltk.updatePackageEnable(p, false));
      Config.curSchemeChanged();
    }
  }

  function refreshGameMode(gameMode) {
    const data = Lua.fn(`function(mode)
      local m = Fk.game_modes[mode]
      return {
        minPlayer = m.minPlayer,
        maxPlayer = m.maxPlayer,
      }
    end`)(gameMode);
    playerNum.from = data.minPlayer;
    playerNum.to = data.maxPlayer;
  }
}
