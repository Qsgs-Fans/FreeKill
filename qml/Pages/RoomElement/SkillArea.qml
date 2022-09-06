import QtQuick 2.15
import QtQuick.Layouts 1.1

Flickable {
  id: root
  property alias skill_buttons: skill_buttons

  width: Math.min(250, contentWidth)
  height: Math.min(180, contentHeight)
  clip: true
  contentWidth: grids.width
  contentHeight: grids.height
  flickableDirection: Flickable.AutoFlickIfNeeded

  ListModel {
    id: active_skills
  }

  ListModel {
    id: not_active_skills
  }

  ColumnLayout {
    id: grids

    GridLayout {
      columns: 2
      columnSpacing: 2
      rowSpacing: 2
      Repeater {
        id: skill_buttons
        model: active_skills
        SkillButton {
          skill: model.skill
          type: "active"
          enabled: model.enabled

          onPressedChanged: {
            if (enabled)
              roomScene.activateSkill(skill, pressed);
          }
        }
      }
    }

    GridLayout {
      columns: 3
      columnSpacing: 2
      rowSpacing: 2
      Repeater {
        model: not_active_skills
        SkillButton {
          skill: model.skill
          type: "notactive"
        }
      }
    }
  }
}
