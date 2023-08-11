// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Item {
  id: root
  anchors.fill: parent
  property var extra_data: ({})
  signal finish()

  Rectangle {
    anchors.fill: parent
    color: "black"

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

    Flickable {
      id: flickableContainer
      ScrollBar.vertical: ScrollBar {}
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 40
      flickableDirection: Flickable.VerticalFlick
      width: parent.width - 20
      height: parent.height - 40
      contentWidth: cardsList.width
      contentHeight: cardsList.height
      clip: true

      ColumnLayout {
        id: cardsList

        GridLayout {
          columns: Math.floor(flickableContainer.width / 100)

          Repeater {
            model: extra_data.ids || extra_data.cardNames

            GeneralCardItem {
              id: cardItem
              // width: (flickableContainer.width - 15) / 4
              // height: cardItem.width * 1.4
              autoBack: false
              name: modelData
            }
          }
        }
      }
    }
  }
}
