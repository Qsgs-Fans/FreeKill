// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
  // anchors.centerIn: parent

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
      maximumLength: 64
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
}
