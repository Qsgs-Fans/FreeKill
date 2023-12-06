// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

ColumnLayout {
  id: root
  anchors.fill: parent
  property var extra_data: ({})
  signal finish()

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: childrenRect.height + 4

    GlowText {
      id: pileName
      text: Backend.translate(extra_data.name)
      width: parent.width
      anchors.topMargin: 10
      horizontalAlignment: Text.AlignHCenter
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

  GridView {
    cellWidth: 93 + 4
    cellHeight: 130 + 4
    Layout.preferredWidth: root.width - root.width % 97
    Layout.fillHeight: true
    Layout.alignment: Qt.AlignHCenter
    clip: true

    model: extra_data.ids || extra_data.cardNames

    delegate: GeneralCardItem {
      id: cardItem
      autoBack: false
      name: modelData
    }
  }
}
