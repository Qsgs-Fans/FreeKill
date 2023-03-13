import QtQuick 2.15
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.15

Item {
  id: root

  width: childrenRect.width
  height: childrenRect.height

  signal finished()

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
              gameMode: gameModeCombo.text,
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
  }
}
