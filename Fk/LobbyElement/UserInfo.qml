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
      text: luatr("Username")
    }
    Text {
      text: Self.screenName
      font.pixelSize: 18
    }
  }

  Timer {
    id: opTimer
    interval: 1000
  }

  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: luatr("Avatar")
    }
    TextField {
      id: avatarName
      maximumLength: 64
      font.pixelSize: 18
      text: Self.avatar
      Layout.fillWidth: true
    }
    Button {
      text: luatr("Update Avatar")
      enabled: avatarName.text !== "" && !opTimer.running
      onClicked: {
        mainWindow.busy = true;
        opTimer.start();
        ClientInstance.notifyServer(
          "UpdateAvatar",
          avatarName.text
        );
      }
    }
  }

  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: luatr("Old Password")
    }
    TextField {
      id: oldPassword
      echoMode: TextInput.Password
      passwordCharacter: "*"
      Layout.rightMargin: 16
      Layout.fillWidth: true
    }
  }

  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: luatr("New Password")
    }
    TextField {
      id: newPassword
      echoMode: TextInput.Password
      passwordCharacter: "*"
      Layout.fillWidth: true
    }
    Button {
      text: luatr("Update Password")
      enabled: oldPassword.text !== "" && newPassword.text !== ""
               && !opTimer.running
      onClicked: {
        mainWindow.busy = true;
        opTimer.start();
        ClientInstance.notifyServer(
          "UpdatePassword",
          [oldPassword.text, newPassword.text]
        );
      }
    }
  }
}
