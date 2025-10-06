// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Widgets as W

Item {
  width: 600
  height: 800

  W.PreferencePage {
    id: prefPage
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: buttonBar.top
    anchors.bottomMargin: 8
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
        id: generalNum
        title: Lua.tr("Select generals num")
        from: 3
        to: 18
        value: Config.preferredGeneralNum

        onValueChanged: {
          Config.preferredGeneralNum = value;
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
      W.SpinRow {
        title: Lua.tr("Choose General timeout")
        from: 10
        to: 60
        editable: true
        value: Config.preferredChooseGeneralTimeout

        onValueChanged: {
          Config.preferredChooseGeneralTimeout = value;
        }
      }
      W.SpinRow {
        title: Lua.tr("Luck Card Times")
        subTitle: Lua.tr("help: Luck Card Times")
        from: 0
        to: 8
        value: Config.preferredLuckTime

        onValueChanged: {
          Config.preferredLuckTime = value;
        }
      }
    }

    W.PreferenceGroup {
      title: Lua.tr("Game Rule")
      W.ComboRow {
        id: gameModeCombo
        title: Lua.tr("Game Mode")
        textRole: "name"
        model: ListModel {
          id: gameModeList
        }

        onCurrentValueChanged: {
          const data = currentValue;
          playerNum.from = data.minPlayer;
          playerNum.to = data.maxPlayer;

          Config.preferedMode = data.orig_name;
        }
      }

      W.SwitchRow {
        id: freeAssignCheck
        // checked: Debugging ? true : false
        checked: Config.enableFreeAssign
        onCheckedChanged: Config.enableFreeAssign = checked;
        title: Lua.tr("Enable free assign")
        subTitle: Lua.tr("help: Enable free assign")
      }

      W.SwitchRow {
        id: deputyCheck
        // checked: Debugging ? true : false
        checked: Config.enableDeputy
        onCheckedChanged: Config.enableDeputy = checked;
        title: Lua.tr("Enable deputy general")
        subTitle: Lua.tr("help: Enable deputy general")
      }
    }


    Component.onCompleted: {
      const mode_data = Lua.call("GetGameModes");
      let i = 0;
      for (let d of mode_data) {
        gameModeList.append(d);
        if (d.orig_name === Config.preferedMode) {
          gameModeCombo.setCurrentIndex(i);
        }
        i += 1;
      }

      playerNum.value = Config.preferedPlayerNum;

      for (let k in Config.curScheme.banPkg) {
        Lua.call("UpdatePackageEnable", k, false);
      }
      Config.curScheme.banCardPkg.forEach(p => Lua.call("UpdatePackageEnable", p, false));
      Config.curScheme = Config.curScheme;
    }
  }

  Rectangle {
    id: buttonBar
    anchors.left: parent.left
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
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        text: Lua.tr("OK")
        // enabled: !(warning.visible)
        onClicked: {
          Config.saveConf();
          root.finish();
          App.setBusy(true);
          let k, arr;

          let disabledGenerals = [];
          for (k in Config.curScheme.banPkg) {
            arr = Config.curScheme.banPkg[k];
            if (arr.length !== 0) {
              const generals = Lua.call("GetGenerals", k);
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

          ClientInstance.notifyServer(
            "CreateRoom",
            [
              roomName.text, playerNum.value,
              Config.preferredTimeout, {
                enableFreeAssign: freeAssignCheck.checked,
                enableDeputy: deputyCheck.checked,
                gameMode: Config.preferedMode,
                disabledPack: disabledPack,
                generalNum: Config.preferredGeneralNum,
                generalTimeout: Config.preferredChooseGeneralTimeout,
                luckTime: Config.preferredLuckTime,
                password: roomPassword.text,
                disabledGenerals,
              }
            ]
          );
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
}
