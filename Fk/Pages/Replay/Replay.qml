// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls

import Fk
import Fk.Widgets as W

W.PageBase {
  id: root

  ListView {
    id: bar
    clip: true
    width: parent.width * 0.2
    height: parent.height
    model: ["Game Data Overview", "Statistics Overview", "Favorite Replay"]
    highlight: Rectangle { color: "lightsteelblue"; radius: 5 }
    delegate: Item {
      width: parent.width
      height: 40

      Text {
        text: Lua.tr(modelData)
        anchors.centerIn: parent
        font.pixelSize: 20
      }

      W.TapHandler {
        onTapped: {
          bar.currentIndex = index;
        }
      }
    }
  }

  SwipeView {
    width: root.width - bar.width - 16
    x: bar.width + 16
    height: root.height
    interactive: false
    orientation: Qt.Vertical
    currentIndex: bar.currentIndex
    GameDataOverview {}
    StatisticsOverview {}
    ReplayRecordingFile {}
  }

  Button {
    text: Lua.tr("Quit")
    anchors.top: parent.top
    anchors.right: parent.right
    onClicked: {
      App.quitPage();
    }
  }
}
