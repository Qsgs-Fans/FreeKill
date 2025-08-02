// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
      title: luatr("Basic settings")
      W.EntryRow {
        id: roomName
        title: luatr("Room Name")
        text: luatr("$RoomName").arg(Self.screenName)
      }
    }

    W.PreferenceGroup {
      W.EntryRow {
        id: roomPassword
        title: luatr("Room Password")
      }
    }

    W.PreferenceGroup {
      title: luatr("Properties")
      W.SpinRow {
        id: playerNum
        title: luatr("Player num")
        from: 2
        to: 12
        value: config.preferedPlayerNum

        onValueChanged: {
          config.preferedPlayerNum = value;
        }
      }
      W.SpinRow {
        id: generalNum
        title: luatr("Select generals num")
        from: 3
        to: 18
        value: config.preferredGeneralNum

        onValueChanged: {
          config.preferredGeneralNum = value;
        }
      }
      W.SpinRow {
        title: luatr("Operation timeout")
        from: 10
        to: 60
        editable: true
        value: config.preferredTimeout

        onValueChanged: {
          config.preferredTimeout = value;
        }
      }
      W.SpinRow {
        title: luatr("Choose General timeout")
        from: 10
        to: 60
        editable: true
        value: config.preferredChooseGeneralTimeout

        onValueChanged: {
          config.preferredChooseGeneralTimeout = value;
        }
      }
      W.SpinRow {
        title: luatr("Luck Card Times")
        subTitle: luatr("help: Luck Card Times")
        from: 0
        to: 8
        value: config.preferredLuckTime

        onValueChanged: {
          config.preferredLuckTime = value;
        }
      }
    }

    W.PreferenceGroup {
      title: luatr("Game Rule")
      W.ComboRow {
        id: gameModeCombo
        title: luatr("Game Mode")
        textRole: "name"
        model: ListModel {
          id: gameModeList
        }

        onCurrentValueChanged: {
          const data = currentValue;
          playerNum.from = data.minPlayer;
          playerNum.to = data.maxPlayer;

          config.preferedMode = data.orig_name;
        }
      }

      W.SwitchRow {
        id: freeAssignCheck
        // checked: Debugging ? true : false
        checked: config.enableFreeAssign
        onCheckedChanged: config.enableFreeAssign = checked;
        title: luatr("Enable free assign")
        subTitle: luatr("help: Enable free assign")
      }

      W.SwitchRow {
        id: deputyCheck
        // checked: Debugging ? true : false
        checked: config.enableDeputy
        onCheckedChanged: config.enableDeputy = checked;
        title: luatr("Enable deputy general")
        subTitle: luatr("help: Enable deputy general")
      }
    }


    Component.onCompleted: {
      const mode_data = lcall("GetGameModes");
      let i = 0;
      for (let d of mode_data) {
        gameModeList.append(d);
        if (d.orig_name === config.preferedMode) {
          gameModeCombo.setCurrentIndex(i);
        }
        i += 1;
      }

      playerNum.value = config.preferedPlayerNum;

      for (let k in config.curScheme.banPkg) {
        lcall("UpdatePackageEnable", k, false);
      }
      config.curScheme.banCardPkg.forEach(p =>
      lcall("UpdatePackageEnable", p, false));
      config.curSchemeChanged();
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
        text: luatr("OK")
        // enabled: !(warning.visible)
        onClicked: {
          config.saveConf();
          root.finish();
          mainWindow.busy = true;
          let k, arr;

          let disabledGenerals = [];
          for (k in config.curScheme.banPkg) {
            arr = config.curScheme.banPkg[k];
            if (arr.length !== 0) {
              const generals = lcall("GetGenerals", k);
              if (generals.length !== 0) {
                disabledGenerals.push(...generals.filter(g => !arr.includes(g)));
              }
            }
          }
          for (k in config.curScheme.normalPkg) {
            arr = config.curScheme.normalPkg[k] ?? [];
            if (arr.length !== 0)
            disabledGenerals.push(...arr);
          }

          let disabledPack = config.curScheme.banCardPkg.slice();
          for (k in config.curScheme.banPkg) {
            if (config.curScheme.banPkg[k].length === 0)
            disabledPack.push(k);
          }
          config.serverHiddenPacks.forEach(p => {
            if (!disabledPack.includes(p)) {
              disabledPack.push(p);
            }
          });

          ClientInstance.notifyServer(
            "CreateRoom",
            [
              roomName.text, playerNum.value,
              config.preferredTimeout, {
                enableFreeAssign: freeAssignCheck.checked,
                enableDeputy: deputyCheck.checked,
                gameMode: config.preferedMode,
                disabledPack: disabledPack,
                generalNum: config.preferredGeneralNum,
                generalTimeout: config.preferredChooseGeneralTimeout,
                luckTime: config.preferredLuckTime,
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
        text: luatr("Cancel")
        onClicked: {
          root.finish();
        }
      }
    }
  }
}
