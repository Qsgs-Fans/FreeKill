// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Fk.ReplayElement
import Fk.Common

Item {
  id: root

  ListView {
    id: bar
    clip: true
    width: parent.width * 0.2
    height: parent.height
    model: ["战绩一览", "数据统计", "已收藏录像"]
    highlight: Rectangle { color: "lightsteelblue"; radius: 5 }
    delegate: Item {
      width: parent.width
      height: 40

      Text {
        text: luatr(modelData)
        anchors.centerIn: parent
        font.pixelSize: 20
      }

      TapHandler {
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
    text: luatr("Quit")
    anchors.top: parent.top
    anchors.right: parent.right
    onClicked: {
      mainStack.pop();
    }
  }
}
