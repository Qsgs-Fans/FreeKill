// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ColumnLayout {
  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: luatr("Lobby BG")
    }
    TextField {
      Layout.fillWidth: true
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
      text: luatr("Room BG")
    }
    TextField {
      Layout.fillWidth: true
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
      text: luatr("Game BGM")
    }
    TextField {
      Layout.fillWidth: true
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

  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: luatr("Poster Girl")
    }
    TextField {
      Layout.fillWidth: true
      text: config.ladyImg
    }
    Button {
      text: "..."
      onClicked: {
        fdialog.nameFilters = ["Image Files (*.jpg *.png)"];
        fdialog.configKey = "ladyImg";
        fdialog.open();
      }
    }
  }

  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: "Language"
    }
    ComboBox {
      model: ["zh_CN", "en_US", "vi_VN"]
      currentIndex: model.indexOf(config.language)
      onCurrentTextChanged: { config.language = currentText; }
    }
  }

  FileDialog {
    id: fdialog
    property string configKey
    onAccepted: { config[configKey] = selectedFile; }
  }
}
