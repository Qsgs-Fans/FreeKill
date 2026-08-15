// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import LunarLtk

ColumnLayout {
  id: root

  required property var skillModel

  Repeater {
    id: rep
    model: root.skillModel
    LimitSkillItem {
      required property var modelData
      // QML BUG:删除ListModel元素会出现undefined的modelData
      readonly property var _m: modelData ?? { skill: "", time: 0 }
      skillname: _m.skill
      usedtimes: _m.time
    }
  }
}
