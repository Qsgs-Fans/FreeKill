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

    Text {
      id: warning
      anchors.rightMargin: 8
      visible: {
        //config.disabledPack; // 没什么用，只是为了禁包刷新时刷新visible罢了
        const avail = lcall("GetAvailableGeneralsNum");
        const ret = avail <
                  config.preferredGeneralNum * config.preferedPlayerNum;
        return ret;
      }
      text: luatr("No enough generals")
      color: "red"
    }

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
        enabled: !(warning.visible)
        onClicked: {
          config.saveConf();
          root.finished();
          mainWindow.busy = true;

          let disabledGenerals = config.disabledGenerals.slice();
          if (disabledGenerals.length) {
            const availablePack = lcall("GetAllGeneralPack").
              filter((pack) => !config.disabledPack.includes(pack));
            disabledGenerals = disabledGenerals.filter((general) => {
              return availablePack.find(pack =>
                lcall("GetGenerals", pack).includes(general));
            });

            disabledGenerals = Array.from(new Set(disabledGenerals));
          }

          let disabledPack = config.disabledPack.slice();
          config.serverHiddenPacks.forEach(p => {
            if (!disabledPack.includes(p)) {
              disabledPack.push(p);
            }
          });
          const generalPacks = lcall("GetAllGeneralPack");
          for (let pk of generalPacks) {
            if (disabledPack.includes(pk)) continue;
            let generals = lcall("GetGenerals", pk);
            let t = generals.filter(g => !disabledGenerals.includes(g));
            if (t.length === 0) {
              disabledPack.push(pk);
              disabledGenerals = disabledGenerals
                .filter(g1 => !generals.includes(g1));
            }
          }

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

      config.disabledPack.forEach(p => lcall("UpdatePackageEnable", p, false));
      config.disabledPackChanged();
    }
  }
}
