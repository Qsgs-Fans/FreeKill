// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk
import Fk.Components.LunarLTK
import Fk.Pages.LunarLTK
import Fk.Components.Common
import Qt5Compat.GraphicalEffects

GraphicsBox {
  id: root

  property var card_names: []
  property var all_names: []
  property string prompt : ""
  property string result : ""

  function processMatrixRowLengthCompact(matrix) {
    /*
      内容由 AI 生成，请仔细甄别：
      输入一个二维数组，取每行元素数组成一个一维数组1，
      对其中的元素{若小于5则取原值，大于4且小于9则取3，否则取其算数平方根（向下取整）}构成一个一维数组2并取其中的最大值，
      对一维数组1中每个元素{除以该值（向上取整）并乘以该值}求和，对该和取算数平方根（向下取整），
      若得到的值大于5，则返回6，小于4，则取其与一维数组2中所有数的最大值。
    */
    const arr1 = matrix.map(row => row?.length || 0);
    if (!arr1.length) return 0;
    
    const arr2 = arr1.map(v => v < 5 ? v : v < 9 ? 3 : Math.floor(Math.sqrt(v)));
    const max2 = Math.max(...arr2);
    if (!max2 || max2 === 0) return 0;
    
    const sum = arr1.reduce((t, v) => t + Math.ceil(v / max2) * max2, 0);
    const sqrtSum = Math.floor(Math.sqrt(sum));
    
    return sqrtSum > 5 ? 6 : sqrtSum < 4 ? Math.max(sqrtSum, Math.max(...arr2)) : sqrtSum;
  }

  property int lines: processMatrixRowLengthCompact(all_names)

  title.text: Util.processPrompt(prompt)
  width: 700
  height: lines * 45 + 20 + 40

  Flickable {
    id : flickableContainer

    // 内容宽度大于可视区域宽度以启用水平滚动
    contentWidth: cardArea.implicitWidth
    contentHeight: cardArea.implicitHeight  // 内容高度与可视区域高度相同，禁用垂直滚动

    anchors.topMargin: Math.max(40, (parent.height - contentHeight) / 2)
    anchors.leftMargin: Math.max(10, (parent.width - contentWidth) / 2)
    anchors.rightMargin: 10
    anchors.bottomMargin: 20
    anchors.fill: parent

    // 只允许水平滚动
    flickableDirection: Flickable.HorizontalFlick
    // 根据内容宽度决定是否可交互
    interactive: contentWidth > parent.width - 20
    // 启用裁剪
    clip: true
    
    Row {
      id: cardArea
      anchors.centerIn: parent
      spacing: 20

      Repeater {
        id: areaRepeater
        model: all_names
        
        delegate : GridLayout {
          id: gridLayout
          columns: Math.ceil(modelData.length / lines)
          columnSpacing : 10
          rowSpacing : 10
          
          Repeater {
            id: cardRepeater
            model: modelData

            delegate: Rectangle {
              id: cardItem
              width : 80
              height : 35
              clip : true
              border.color: "#FEF7D6"
              border.width: 2
              radius : 2

              enabled : root.card_names.includes(modelData)

              layer.effect: DropShadow {
                color: "#845422"
                radius: 5
                samples: 25
                spread: 0.7
              }

              Rectangle {
                id : cardImageArea
                anchors.centerIn: parent
                width : parent.width - 4
                height : parent.height - 4
                color: "transparent"
                clip : true
                Image {
                  id: cardImage
                  // anchors.fill: parent
                  anchors.centerIn: parent
                  // anchors.topMargin: -20
                  source: SkinBank.getCardPicture(modelData)
                  // fillMode: Image.PreserveAspectCrop
                  sourceClipRect: Qt.rect(6, 53, parent.width, parent.height)
                  scale : 1.05
                }
              }

              Rectangle {
                id : cardGrey
                anchors.fill: parent
                anchors.centerIn: parent
                visible: !this.enabled
                color: Qt.rgba(0, 0, 0, 0.7)
                opacity: 0.7
                z: 2
              }

              GlowText {
                id : cardName
                text: Lua.tr(modelData)
                visible : true
                font.family: Config.li2Name
                font.pixelSize: 15
                font.bold: true
                color : "#111111"
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
                  result = modelData;
                  root.close();
                }


              }

            }
          }

        }

      }
    }

    
  }

}
