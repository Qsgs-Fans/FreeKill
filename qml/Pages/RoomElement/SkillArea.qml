import QtQuick
import QtQuick.Layouts

Flickable {
  id: root
  property alias skill_buttons: skill_buttons

  clip: true
  contentWidth: panel.width
  contentHeight: panel.height
  width: panel.width
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
    let data = JSON.parse(Backend.callLuaFunction(
      "GetSkillData",
      [skill_name]
    ));
    if (data.freq = "active") {
      active_skills.append(data);
    } else {
      not_active_skills.append(data);
    }
  }

  function loseSkill(skill_name) {
    for (let i = 0; i < active_skills.count; i++) {
      let item = active_skills.at(i);
      if (item.skill == skill_name) {
        active_skills.remove(i);
      }
    }
    for (let i = 0; i < not_active_skills.count; i++) {
      let item = not_active_skills.at(i);
      if (item.skill == skill_name) {
        not_active_skills.remove(i);
      }
    }
  }
}
