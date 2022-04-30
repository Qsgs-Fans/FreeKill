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
        text: Backend.translate("Username")
      }
      Text {
        text: Self.screenName
        font.pixelSize: 18
      }
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("Avatar")
      }
      TextField {
        id: avatarName
        font.pixelSize: 18
        text: Self.avatar
      }
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("Old Password")
      }
      TextField {
        id: oldPassword
        echoMode: TextInput.Password
        passwordCharacter: "*"
      }
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("New Password")
      }
      TextField {
        id: newPassword
        echoMode: TextInput.Password
        passwordCharacter: "*"
      }
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Button {
        text: Backend.translate("Update Avatar")
        enabled: avatarName.text !== ""
        onClicked: {
          mainWindow.busy = true;
          ClientInstance.notifyServer(
            "UpdateAvatar",
            JSON.stringify([avatarName.text])
          );
        }
      }
      Button {
        text: Backend.translate("Update Password")
        enabled: oldPassword.text !== "" && newPassword.text !== ""
        onClicked: {
          mainWindow.busy = true;
          ClientInstance.notifyServer(
            "UpdatePassword",
            JSON.stringify([oldPassword.text, newPassword.text])
          );
        }
      }
      Button {
        text: Backend.translate("Quit")
        onClicked: {
          root.finished();
        }
      }
    }
  }
}
