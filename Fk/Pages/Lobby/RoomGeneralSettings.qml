// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Widgets as W

Item {
  width: 600
  height: 800

  readonly property alias roomName: roomName.text
  readonly property alias playerNum: playerNum.value
  readonly property alias roomPassword: roomPassword.text

  W.PreferencePage {
    id: prefPage
    anchors.fill: parent
    groupWidth: width * 0.8
    W.PreferenceGroup {
      title: Lua.tr("Basic settings")
      W.EntryRow {
        id: roomName
        title: Lua.tr("Room Name")
        text: Lua.tr("$RoomName").arg(Self.screenName)
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
        from: 2
        to: 12
        value: Config.preferedPlayerNum

        onValueChanged: {
          Config.preferedPlayerNum = value;
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
        }
      }
    }

    Component.onCompleted: {
      playerNum.value = Config.preferedPlayerNum;

      for (let k in Config.curScheme.banPkg) {
        Lua.call("UpdatePackageEnable", k, false);
      }
      Config.curScheme.banCardPkg.forEach(p => Lua.call("UpdatePackageEnable", p, false));
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
