import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import LunarLtk

RowLayout {
  id: root
  required property PhotoModel dataModel
  spacing: 5

  Repeater {
    model: root.dataModel.targetTip

    Item {
      required property var modelData
      // Layout.alignment: Qt.AlignHCenter
      width: modelData.type === "normal" ? 30 : 18

      GlowText {
        anchors.centerIn: parent
        visible: parent.modelData.type === "normal"
        text: parent.modelData.content
        font.family: Config.li2Name
        color: "#FEFE84"
        font.pixelSize: {
          if (text.length <= 3) return 27;
          else return 21;
        }
        //font.bold: true
        glow.color: "black"
        glow.spread: 0.3
        glow.radius: 4
        lineHeight: 0.85
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WrapAnywhere
        width: font.pixelSize + 4
      }

      Text {
        anchors.centerIn: parent
        visible: parent.modelData.type === "warning"
        font.family: Config.libianName
        font.pixelSize: 18
        opacity: 0.9
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 18
        lineHeightMode: Text.FixedHeight
        //color: "#EAC28A"
        color: "snow"
        width: 18
        wrapMode: Text.WrapAnywhere
        style: Text.Outline
        //styleColor: "#83231F"
        styleColor: "red"
        text: parent.modelData.content
      }
    }
  }
}
