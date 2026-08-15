// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import LunarLtk

Flickable {
  id: root

  required property DashboardModel dataModel
  property alias skill_buttons: skill_buttons
  property alias prelight_buttons: prelight_buttons
  property alias not_active_buttons: not_active_buttons

  clip: true
  contentWidth: panel.width
  contentHeight: panel.height
  contentX: contentWidth - width
  width: Math.min(180, panel.width)
  height: Math.min(200, panel.height)
  flickableDirection: Flickable.AutoFlickIfNeeded

  property list<SkillModel> activeSkills: [];
  property list<SkillModel> nonactiveSkills: [];

  Connections {
    target: root.dataModel
    function onSkillsChanged() {
      root.activeSkills = root.dataModel.skills.filter(e => e.isActive);
      root.nonactiveSkills = root.dataModel.skills.filter(e => !e.isActive);
    }
  }

  Item {
    id: panel
    width: Math.max(grid0.width, grid1.width, grid2.width)
    height: grid0.height + grid1.height + grid2.height
    Grid {
      id: grid0
      // FIXME: 得优化成类似mark区域那种自动化布局才行啊，可惜鸽
      columns: Config.language.startsWith('zh') ? 2 : 1
      columnSpacing: 2
      rowSpacing: 2
      Repeater {
        id: prelight_buttons
        model: root.dataModel.fakeSkills
        onItemAdded: parent.forceLayout()
        SkillButton {
          required property SkillModel modelData
          dataModel: modelData
        }
      }
    }

    Grid {
      id: grid1
      anchors.top: grid0.bottom
      columns: Config.language.startsWith('zh') ? 2 : 1
      columnSpacing: 2
      rowSpacing: 2
      Repeater {
        id: skill_buttons
        model: root.activeSkills
        onItemAdded: parent.forceLayout()
        SkillButton {
          required property SkillModel modelData
          dataModel: modelData
        }
      }
    }

    Grid {
      id: grid2
      anchors.top: grid1.bottom
      anchors.topMargin: 2
      columns: Config.language.startsWith('zh') ? 3 : 1
      columnSpacing: 2
      rowSpacing: 2
      Repeater {
        id: not_active_buttons
        model: root.nonactiveSkills
        onItemAdded: parent.forceLayout()
        SkillButton {
          required property SkillModel modelData
          dataModel: modelData
        }
      }
    }
  }

  function syncSkills() {
  }
}
