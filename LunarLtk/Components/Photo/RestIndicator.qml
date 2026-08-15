import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import LunarLtk

ColumnLayout {
  id: root
  required property PhotoModel dataModel
  visible: dataModel.rest > 0

  GlowText {
    Layout.alignment: Qt.AlignCenter
    text: Lua.tr("resting...")
    font.family: Config.libianName
    font.pixelSize: 30
    font.bold: true
    color: "#FEF7D6"
    glow.color: "#845422"
    glow.spread: 0.8
  }

  GlowText {
    Layout.alignment: Qt.AlignCenter
    visible: root.dataModel.rest > 0 && root.dataModel.rest < 999
    text: root.dataModel.rest
    font.family: Config.libianName
    font.pixelSize: 25
    font.bold: true
    color: "#DBCC69"
    glow.color: "#2E200F"
    glow.spread: 0.6
  }

  GlowText {
    Layout.alignment: Qt.AlignCenter
    visible: root.dataModel.rest > 0 && root.dataModel.rest < 999
    text: Lua.tr("rest round num")
    font.family: Config.libianName
    font.pixelSize: 21
    color: "#F0E5D6"
    glow.color: "#2E200F"
    glow.spread: 0.6
  }
}

