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
    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("Room Name")
      }
      TextField {
        id: roomName
        maximumLength: 64
        font.pixelSize: 18
        text: Backend.translate("$RoomName").arg(Self.screenName)
      }
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("Player num")
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
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("Game Mode")
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

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("Select generals num")
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
    }

    Text {
      id: warning
      anchors.rightMargin: 8
      visible: {
        //config.disabledPack; // 没什么用，只是为了禁包刷新时刷新visible罢了
        const avail = JSON.parse(Backend.callLuaFunction("GetAvailableGeneralsNum", []));
        const ret = avail < config.preferredGeneralNum * config.preferedPlayerNum;
        return ret;
      }
      text: Backend.translate("No enough generals")
      color: "red"
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("Operation timeout")
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
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("Luck Card Times")
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

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("Room Password")
      }
      TextField {
        id: roomPassword
        maximumLength: 16
        font.pixelSize: 18
      }
    }

    Switch {
      id: freeAssignCheck
      checked: Debugging ? true : false
      text: Backend.translate("Enable free assign")
    }

    Switch {
      id: deputyCheck
      checked: Debugging ? true : false
      text: Backend.translate("Enable deputy general")
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Button {
        text: Backend.translate("OK")
        enabled: !(warning.visible)
        onClicked: {
          config.saveConf();
          root.finished();
          mainWindow.busy = true;

          let disabledGenerals = config.disabledGenerals.slice();
          if (disabledGenerals.length) {
            const availablePack = JSON.parse(Backend.callLuaFunction("GetAllGeneralPack", [])).
              filter((pack) => !config.disabledPack.includes(pack));
            disabledGenerals = disabledGenerals.filter((general) => {
              return availablePack.find((pack) => JSON.parse(Backend.callLuaFunction("GetGenerals", [pack])).includes(general));
            });

            disabledGenerals = Array.from(new Set(disabledGenerals));
          }

          let disabledPack = config.disabledPack.slice();
          config.serverHiddenPacks.forEach(p => {
            if (!disabledPack.includes(p)) {
              disabledPack.push(p);
            }
          });
          const generalPacks = JSON.parse(Backend.callLuaFunction("GetAllGeneralPack", []));
          for (let pk of generalPacks) {
            if (disabledPack.includes(pk)) continue;
            let generals = JSON.parse(Backend.callLuaFunction("GetGenerals", [pk]));
            let t = generals.filter(g => !disabledGenerals.includes(g));
            if (t.length === 0) {
              disabledPack.push(pk);
              disabledGenerals = disabledGenerals.filter(g1 => !generals.includes(g1));
            }
          }

          ClientInstance.notifyServer(
            "CreateRoom",
            JSON.stringify([roomName.text, playerNum.value, config.preferredTimeout, {
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
        text: Backend.translate("Cancel")
        onClicked: {
          root.finished();
        }
      }
    }

    Component.onCompleted: {
      const mode_data = JSON.parse(Backend.callLuaFunction("GetGameModes", []));
      let i = 0;
      for (let d of mode_data) {
        gameModeList.append(d);
        if (d.orig_name == config.preferedMode) {
          gameModeCombo.currentIndex = i;
        }
        i += 1;
      }

      playerNum.value = config.preferedPlayerNum;

      config.disabledPack.forEach(p => {
        Backend.callLuaFunction("UpdatePackageEnable", [p, false]);
      });
      config.disabledPackChanged();
    }
  }
}
