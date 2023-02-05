import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

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
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("Lobby BG")
      }
      TextField {
        text: config.lobbyBg
      }
      Button {
        text: "..."
        onClicked: {
          fdialog.nameFilters = ["Image Files (*.jpg *.png)"];
          fdialog.configKey = "lobbyBg";
          fdialog.open();
        }
      }
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("Room BG")
      }
      TextField {
        text: config.roomBg
      }
      Button {
        text: "..."
        onClicked: {
          fdialog.nameFilters = ["Image Files (*.jpg *.png)"];
          fdialog.configKey = "roomBg";
          fdialog.open();
        }
      }
    }

    RowLayout {
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Backend.translate("Game BGM")
      }
      TextField {
        text: config.bgmFile
      }
      Button {
        text: "..."
        onClicked: {
          fdialog.nameFilters = ["Music Files (*.mp3)"];
          fdialog.configKey = "bgmFile";
          fdialog.open();
        }
      }
    }
  }

  FileDialog {
    id: fdialog
    property string configKey
    onAccepted: { config[configKey] = selectedFile; }
  }
}
