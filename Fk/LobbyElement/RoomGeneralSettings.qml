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
        to: 8
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
          let data = gameModeList.get(currentIndex);
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
        text: Backend.translate("Select general num")
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
        onClicked: {
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

          ClientInstance.notifyServer(
            "CreateRoom",
            JSON.stringify([roomName.text, playerNum.value, config.preferredTimeout, {
              enableFreeAssign: freeAssignCheck.checked,
              enableDeputy: deputyCheck.checked,
              gameMode: config.preferedMode,
              disabledPack: config.disabledPack,
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
      let mode_data = JSON.parse(Backend.callLuaFunction("GetGameModes", []));
      let i = 0;
      for (let d of mode_data) {
        gameModeList.append(d);
        if (d.orig_name == config.preferedMode) {
          gameModeCombo.currentIndex = i;
        }
        i += 1;
      }

      playerNum.value = config.preferedPlayerNum;
    }
  }
}
