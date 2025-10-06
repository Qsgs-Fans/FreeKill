// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import Fk

ColumnLayout {
  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: Lua.tr("Lobby BG")
    }
    TextField {
      Layout.fillWidth: true
      text: Config.lobbyBg
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
      text: Lua.tr("Room BG")
    }
    TextField {
      Layout.fillWidth: true
      text: Config.roomBg
    }
    Button {
      text: "..."
      onClicked: {
        fdialog.nameFilters = ["媒体文件 (*.png *.jpg *.jpeg *.gif *.mp4"];
        fdialog.configKey = "roomBg";
        fdialog.open();
      }
    }
  }

  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: Lua.tr("Game BGM")
    }
    TextField {
      Layout.fillWidth: true
      text: Config.bgmFile
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
      text: Lua.tr("Poster Girl")
    }
    TextField {
      Layout.fillWidth: true
      text: Config.ladyImg
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
      currentIndex: model.indexOf(Config.language)
      onCurrentTextChanged: { Config.language = currentText; }
    }
  }

  FileDialog {
    id: fdialog
    property string configKey
    onAccepted: { Config[configKey] = selectedFile; }
  }
}
