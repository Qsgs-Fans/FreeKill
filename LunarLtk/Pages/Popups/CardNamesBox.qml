// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Components.Common

import LunarLtk
import LunarLtk.Models.Popups

GraphicsBox {
  id: root

  required property ChoicesModel dataModel

  readonly property int lines: processMatrixRowLengthCompact(dataModel.allChoices)

  title.text: dataModel.promptText
  width: 700
  height: lines * 45 + 20 + 40

  Flickable {
    contentWidth: cardArea.implicitWidth
    contentHeight: cardArea.implicitHeight

    anchors.topMargin: Math.max(40, (parent.height - contentHeight) / 2)
    anchors.leftMargin: Math.max(10, (parent.width - contentWidth) / 2)
    anchors.rightMargin: 10
    anchors.bottomMargin: 20
    anchors.fill: parent

    flickableDirection: Flickable.HorizontalFlick
    interactive: contentWidth > parent.width - 20
    clip: true

    Row {
      id: cardArea
      anchors.centerIn: parent
      spacing: 20

      Repeater {
        model: root.dataModel.allChoices

        delegate: GridLayout {
          required property var modelData
          columns: Math.ceil(modelData.length / root.lines)
          columnSpacing: 10
          rowSpacing: 10

          Repeater {
            id: cardRepeater
            model: parent.modelData

            delegate: Rectangle {
              id: cardItem
              required property string modelData
              width: 80
              height: 35
              clip: true
              border.color: "#FEF7D6"
              border.width: 2
              radius: 2

              enabled: root.dataModel.choices.includes(modelData)

              layer.effect: DropShadow {
                color: "#845422"
                radius: 5
                samples: 25
                spread: 0.7
              }

              Rectangle {
                id: cardImageArea
                anchors.centerIn: parent
                width: parent.width - 4
                height: parent.height - 4
                color: "transparent"
                clip: true
                Image {
                  id: cardImage
                  anchors.centerIn: parent
                  source: SkinBank.getCardPicture(cardItem.modelData)
                  sourceClipRect: Qt.rect(6, 53, parent.width, parent.height)
                  scale : 1.05
                }
              }

              Rectangle {
                id: cardGrey
                anchors.fill: parent
                anchors.centerIn: parent
                visible: !this.enabled
                color: Qt.rgba(0, 0, 0, 0.7)
                opacity: 0.7
                z: 2
              }

              GlowText {
                id : cardName
                text: Lua.tr(cardItem.modelData)
                visible: true
                font.family: Config.li2Name
                font.pixelSize: 15
                font.bold: true
                color: "#111111"
                glow.color: "#EEEEEE"
                glow.spread: 0.6
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.rightMargin: 1
              }

              MouseArea {
                anchors.fill: parent
                anchors.centerIn: parent
                onClicked: {
                  root.dataModel.toggleChoose(cardItem.modelData);
                  root.close();
                }
              }
            }
          }
        }
      }
    }
  }

  function processMatrixRowLengthCompact(matrix) {
    const arr1 = matrix.map(row => row?.length || 0);
    if (!arr1.length) return 0;

    const arr2 = arr1.map(v => v < 5 ? v : v < 9 ? 3 : Math.floor(Math.sqrt(v)));
    const max2 = Math.max(...arr2);
    if (!max2 || max2 === 0) return 0;

    const sum = arr1.reduce((t, v) => t + Math.ceil(v / max2) * max2, 0);
    const sqrtSum = Math.floor(Math.sqrt(sum));

    return sqrtSum > 5 ? 6 : sqrtSum < 4 ? Math.max(sqrtSum, Math.max(...arr2)) : sqrtSum;
  }
}
