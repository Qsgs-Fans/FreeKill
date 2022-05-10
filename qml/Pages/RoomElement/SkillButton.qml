import QtQuick 2.15
import QtGraphicalEffects 1.0

Item {
  id: root
  property alias skill: skill.text
  property string type: "active"
  property bool pressed: false

  onEnabledChanged: {
    if (!enabled)
      pressed = false;
  }

  width: type === "active" ? 120 : 72
  height: type === "active" ? 55 : 36

  Image {
    x: -13
    y: -6
    source: type !== "active" ? ""
      : AppPath + "/image/button/skill/active/"
      + (enabled ? (pressed ? "pressed" : "normal") : "disabled")
  }

  Text {
    anchors.centerIn: parent
    id: skill
    text: "制衡"
    font.family: fontLi2.name
    font.pixelSize: 36
    visible: false
  }

  Glow {
    id: glowItem
    source: skill
    anchors.fill: skill
    radius: 6
    samples: 8
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