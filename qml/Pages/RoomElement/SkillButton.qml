import QtQuick
import Qt5Compat.GraphicalEffects

Item {
  id: root
  property alias skill: skill.text
  property string type: "active"
  property string orig: ""
  property bool pressed: false

  onEnabledChanged: {
    if (!enabled)
      pressed = false;
  }

  width: type === "active" ? Math.max(80, skill.width + 8) : skill.width
  height: type === "active" ? 36 : 24

  Image {
    x: -13 - 120 * 0.166
    y: -6 - 55 * 0.166
    scale: 0.66
    source: type !== "active" ? ""
      : AppPath + "/image/button/skill/active/"
      + (enabled ? (pressed ? "pressed" : "normal") : "disabled")
  }

  Text {
    anchors.centerIn: parent
    id: skill
    font.family: fontLi2.name
    font.pixelSize: Math.max(26 - text.length, 18)
    visible: false
  }

  Glow {
    id: glowItem
    source: skill
    anchors.fill: skill
    radius: 6
    //samples: 8
    color: "grey"
  }

  LinearGradient  {
    anchors.fill: skill
    source: skill
    gradient: Gradient {
      GradientStop { position: 0; color: "#FFE07C" }
      GradientStop { position: 1; color: "#B79A5F" }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    enabled: root.type === "active" && root.enabled
    onClicked: parent.pressed = !parent.pressed;
  }
}
