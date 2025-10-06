// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk

Flickable {
  id: root
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

  ListModel {
    id: prelight_skills
  }

  ListModel {
    id: active_skills
  }

  ListModel {
    id: not_active_skills
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
        model: prelight_skills
        onItemAdded: parent.forceLayout()
        SkillButton {
          skill: model.skill
          type: "prelight"
          enabled: !Config.observing
          orig: model.orig_skill

          onPressedChanged: {
            if (!pressed) return;
            enabled = false;
            ClientInstance.notifyServer("PushRequest", [
              "prelight", orig, (!prelighted).toString()
            ].join(","));
          }
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
        model: active_skills
        onItemAdded: parent.forceLayout()
        SkillButton {
          skill: model.skill
          type: "active"
          enabled: false
          orig: model.orig_skill

          onPressedChanged: {
            if (enabled)
              roomScene.activateSkill(orig, pressed, "click");
          }

          onDoubleTappedChanged: {
            if (doubleTapped && enabled) {
              roomScene.activateSkill(orig, true, "doubleClick");
              doubleTapped = false;
            }
          }
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

  function addSkill(skill_name, prelight) {
    const modelContains = (m, e) => {
      for (let i = 0; i < m.count; i++) {
        if (m.get(i).orig_skill === e.orig_skill) {
          return true;
        }
      }
      return false;
    };

    const data = Lua.call("GetSkillData", skill_name);

    if (prelight) {
      if (!modelContains(prelight_skills, data))
        prelight_skills.append(data);
      return;
    }

    if (data.freq === "active") {
      if (!modelContains(active_skills, data)) active_skills.append(data);
    } else {
      if (!modelContains(not_active_skills, data))
        not_active_skills.append(data);
    }
  }

  function loseSkill(skill_name, prelight) {
    if (prelight) {
      for (let i = 0; i < prelight_skills.count; i++) {
        const item = prelight_skills.get(i);
        if (item.orig_skill == skill_name) {
          prelight_skills.remove(i);
        }
      }
      return;
    }

    for (let i = 0; i < active_skills.count; i++) {
      const item = active_skills.get(i);
      if (item.orig_skill == skill_name) {
        active_skills.remove(i);
      }
    }
    for (let i = 0; i < not_active_skills.count; i++) {
      const item = not_active_skills.get(i);
      if (item.orig_skill == skill_name) {
        not_active_skills.remove(i);
      }
    }
  }

  function clearSkills() {
    prelight_skills.clear();
    active_skills.clear();
    not_active_skills.clear();
  }
}
