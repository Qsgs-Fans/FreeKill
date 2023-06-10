// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
  anchors.fill: parent
  anchors.margins: 16
  signal finished()

  Text {
    text: qsTr("help_text")
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }

  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: qsTr("username")
    }
    TextField {
      id: userName
      font.pixelSize: 18
      text: modConfig.userName
      Layout.fillWidth: true
      onTextChanged: {
        modConfig.userName = text;
        modConfig.saveConf();
      }
    }
  }

  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: qsTr("email")
    }
    TextField {
      id: emailAddr
      font.pixelSize: 18
      Layout.fillWidth: true
      text: modConfig.email
      onTextChanged: {
        modConfig.email = text;
        modConfig.saveConf();
      }
    }
  }

  Text {
    text: qsTr("key_help_text")
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    textFormat: Text.RichText
    onLinkActivated: Qt.openUrlExternally(link);
  }

  Button {
    text: qsTr("copy pubkey")
    Layout.fillWidth: true
    onClicked: {
      const key = "mymod/id_rsa.pub";
      if (!Backend.exists(key)) {
        ModBackend.initKey();
      }
      const pubkey = ModBackend.readFile(key);
      Backend.copyToClipboard(pubkey);
      toast.show(qsTr("pubkey copied"));
    }
  }
}
