// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
  flickableDirection: Flickable.AutoFlickIfNeeded
  clip: true
  contentHeight: layout.height

  ColumnLayout {
    id: layout
    width: parent.width
    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: luatr("Room Name")
      }
      TextField {
        id: roomName
        maximumLength: 64
        font.pixelSize: 18
        Layout.rightMargin: 16
        Layout.fillWidth: true
        text: luatr("$RoomName").arg(Self.screenName)
      }
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: luatr("Game Mode")
      }
      ComboBox {
        id: gameModeCombo
        textRole: "name"
        model: ListModel {
          id: gameModeList
        }

        onCurrentIndexChanged: {
          const data = gameModeList.get(currentIndex);
          playerNum.from = data.minPlayer;
          playerNum.to = data.maxPlayer;

          config.preferedMode = data.orig_name;
        }
      }
    }

    GridLayout {
      anchors.rightMargin: 8
      rowSpacing: 20
      columnSpacing: 20
      columns: 4
      Text {
        text: luatr("Player num")
      }
      Text {
        text: luatr("Select generals num")
      }
      Text {
        text: luatr("Operation timeout")
      }
      Text {
        text: luatr("Luck Card Times")
      }
      SpinBox {
        id: playerNum
        from: 2
        to: 12
        value: config.preferedPlayerNum

        onValueChanged: {
          config.preferedPlayerNum = value;
        }
      }
      SpinBox {
        id: generalNum
        from: 3
        to: 18
        value: config.preferredGeneralNum

        onValueChanged: {
          config.preferredGeneralNum = value;
        }
      }
      SpinBox {
        from: 10
        to: 60
        editable: true
        value: config.preferredTimeout

        onValueChanged: {
          config.preferredTimeout = value;
        }
      }
      SpinBox {
        from: 0
        to: 8
        value: config.preferredLuckTime

        onValueChanged: {
          config.preferredLuckTime = value;
        }
      }
    }

    /*
    Text {
      id: warning
      anchors.rightMargin: 8
      visible: {
        const avail = lcall("GetAvailableGeneralsNum");
        const ret = avail <
                  config.preferredGeneralNum * config.preferedPlayerNum;
        return ret;
      }
      text: luatr("No enough generals")
      color: "red"
    }
    */

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: luatr("Room Password")
      }
      TextField {
        id: roomPassword
        maximumLength: 16
        font.pixelSize: 18
        Layout.rightMargin: 16
        Layout.fillWidth: true
      }
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Switch {
        id: freeAssignCheck
        checked: Debugging ? true : false
        text: luatr("Enable free assign")
      }

      Switch {
        id: deputyCheck
        checked: Debugging ? true : false
        text: luatr("Enable deputy general")
      }
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Button {
        text: luatr("OK")
        // enabled: !(warning.visible)
        onClicked: {
          config.saveConf();
          root.finished();
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
            JSON.stringify([roomName.text, playerNum.value,
                            config.preferredTimeout, {
              enableFreeAssign: freeAssignCheck.checked,
              enableDeputy: deputyCheck.checked,
              gameMode: config.preferedMode,
              disabledPack: disabledPack,
              generalNum: config.preferredGeneralNum,
              luckTime: config.preferredLuckTime,
              password: roomPassword.text,
              disabledGenerals,
            }])
          );
        }
      }
      Button {
        text: luatr("Cancel")
        onClicked: {
          root.finished();
        }
      }
    }

    Component.onCompleted: {
      const mode_data = lcall("GetGameModes");
      let i = 0;
      for (let d of mode_data) {
        gameModeList.append(d);
        if (d.orig_name === config.preferedMode) {
          gameModeCombo.currentIndex = i;
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
}
