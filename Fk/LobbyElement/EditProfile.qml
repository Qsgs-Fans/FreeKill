// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root

  signal finished()

  TabBar {
    id: bar
    y: -height
    transformOrigin: Item.BottomLeft
    rotation: 90
    width: root.height
    background: Rectangle { color: "#EEEEEEEE" }
    TabButton {
      text: luatr("Userinfo Settings")
    }
    TabButton {
      text: luatr("BG Settings")
    }
    TabButton {
      text: luatr("Audio Settings")
    }
  }

  SwipeView {
    width: root.width - bar.height - 16
    x: bar.height + 16
    height: root.height
    interactive: false
    orientation: Qt.Vertical
    currentIndex: bar.currentIndex
    UserInfo {}
    BGSetting {}
    AudioSetting {}
  }
}
