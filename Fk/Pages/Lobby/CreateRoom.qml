// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls

import Fk.Widgets as W

Item {
  id: root
  anchors.fill: parent

  signal finish()

  W.SideBarSwitcher {
    id: bar
    width: 200
    height: parent.height
    model: ListModel {
      ListElement { name: "General Settings" }
      ListElement { name: "Package Settings" }
      ListElement { name: "Ban General Settings" }
    }
  }

  SwipeView {
    width: root.width - bar.width - 16
    x: bar.width + 16
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
