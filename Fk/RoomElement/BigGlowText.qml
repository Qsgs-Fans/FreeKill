import QtQuick
import Qt5Compat.GraphicalEffects

Item {
  property alias text: pileName.text
  GlowText {
    id: pileName
    horizontalAlignment: Text.AlignHCenter
    width: parent.width
    font.family: fontLibian.name
    color: "#E4D5A0"
    font.pixelSize: 30
    font.weight: Font.Medium
    glow.color: "black"
    glow.spread: 0.3
    glow.radius: 5
  }

  LinearGradient  {
    anchors.fill: pileName
    source: pileName
    gradient: Gradient {
      GradientStop {
        position: 0
        color: "#FEF7C2"
      }

      GradientStop {
        position: 0.5
        color: "#D2AD4A"
      }

      GradientStop {
        position: 1
        color: "#BE9878"
      }
    }
  }
}
