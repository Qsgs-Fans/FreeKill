import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
  spacing: 20

  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: Backend.translate("Room Name")
    }
    TextField {
      id: roomName
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
      }
    }
  }

  CheckBox {
    id: freeAssignCheck
    checked: Debugging ? true : false
    text: Backend.translate("Enable free assign")
  }

  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Button {
      text: Backend.translate("OK")
      onClicked: {
        root.finished();
        mainWindow.busy = true;
        ClientInstance.notifyServer(
          "CreateRoom",
          JSON.stringify([roomName.text, playerNum.value, {
            enableFreeAssign: freeAssignCheck.checked,
            gameMode: gameModeList.get(gameModeCombo.currentIndex).orig_name,
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
    for (let d of mode_data) {
      gameModeList.append(d);
    }
    gameModeCombo.currentIndex = 0;
  }
}
