// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
      ListElement { name: "Userinfo Settings" }
      ListElement { name: "BG Settings" }
      ListElement { name: "Audio Settings" }
      ListElement { name: "Control Settings" }
    }
  }

  SwipeView {
    width: root.width - bar.width - 16
    x: bar.width + 16
    height: root.height
    interactive: false
    orientation: Qt.Vertical
    currentIndex: bar.currentIndex
    UserInfo {}
    BGSetting {}
    AudioSetting {}
    ControlSetting {}
  }
}
