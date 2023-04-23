// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

Flickable {
  id: root
  property alias skill_buttons: skill_buttons

  clip: true
  contentWidth: panel.width
  contentHeight: panel.height
  contentX: contentWidth - width
  width: Math.min(150, panel.width)
  height: Math.min(180, panel.height)
  flickableDirection: Flickable.AutoFlickIfNeeded

  ListModel {
    id: active_skills
  }

  ListModel {
    id: not_active_skills
  }

  Item {
    id: panel
    width: Math.max(grid1.width, grid2.width)
    height: grid1.height + grid2.height
    Grid {
      id: grid1
      columns: 2
      columnSpacing: 2
      rowSpacing: 2
      Repeater {
        id: skill_buttons
        model: active_skills
        onItemAdded: parent.forceLayout()
        SkillButton {
          skill: model.skill
          type: "active"
          enabled: false
          orig: model.orig_skill

          onPressedChanged: {
            if (enabled)
              roomScene.activateSkill(orig, pressed);
          }
        }
      }
    }

    Grid {
      id: grid2
      anchors.top: grid1.bottom
      anchors.topMargin: 2
      columns: 3
      columnSpacing: 2
      rowSpacing: 2
      Repeater {
        model: not_active_skills
        onItemAdded: parent.forceLayout()
        SkillButton {
          skill: model.skill
          orig: model.orig_skill
          type: "notactive"
        }
      }
    }
  }

  function addSkill(skill_name) {
    const modelContains = (m, e) => {
      for (let i = 0; i < m.count; i++) {
        if (m.get(i).orig_skill === e.orig_skill) {
          return true;
        }
      }
      return false;
    };

    let data = JSON.parse(Backend.callLuaFunction(
      "GetSkillData",
      [skill_name]
    ));
    if (data.freq === "active") {
      if (!modelContains(active_skills, data)) active_skills.append(data);
    } else {
      if (!modelContains(not_active_skills, data))
        not_active_skills.append(data);
    }
  }

  function loseSkill(skill_name) {
    for (let i = 0; i < active_skills.count; i++) {
      let item = active_skills.get(i);
      if (item.orig_skill == skill_name) {
        active_skills.remove(i);
      }
    }
    for (let i = 0; i < not_active_skills.count; i++) {
      let item = not_active_skills.get(i);
      if (item.orig_skill == skill_name) {
        not_active_skills.remove(i);
      }
    }
  }
}
