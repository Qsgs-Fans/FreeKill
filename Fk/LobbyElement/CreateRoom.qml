// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  anchors.fill: parent

  signal finished()

  TabBar {
    id: bar
    y: -height
    transformOrigin: Item.BottomLeft
    rotation: 90
    width: root.height
    TabButton {
      text: Backend.translate("General Settings")
    }
    TabButton {
      text: Backend.translate("Package Settings")
    }
    TabButton {
      text: Backend.translate("Ban General Settings")
    }
  }

  SwipeView {
    width: root.width - bar.height - 16
    x: bar.height + 16
    height: root.height
    interactive: false
    orientation: Qt.Vertical
    currentIndex: bar.currentIndex
    RoomGeneralSettings {}
    Item {
      RoomPackageSettings {
        anchors.fill: parent
      }
    }
    BanGeneralSetting {}
  }
}
