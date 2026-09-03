import QtQuick

import Fk
import Fk.Components.GameCommon
import LunarLtk.Components.Photo

BasicItem {
  id: root
  width: childrenRect.width
  height: childrenRect.height

  property string general: ""
  property string skinName: ""
  property alias text: skinName.text

  SkinArea {
    id: skinImg
    general: root.general
    skinName: root.skinName
    anchors.centerIn: border
    width: 114
    height: 164
  }

  Rectangle {
    id: border
    width: 120
    height: 170
    color: "transparent"
    border.width: 3
    border.color: "black"
  }

  Text {
    id: skinName
    text: ""
    font.pixelSize: 15
    font.family: "LiSu"
    font.bold: true
    anchors.bottom: skinImg.top
    anchors.horizontalCenter: skinImg.horizontalCenter
    color: "white"
    style: Text.Outline
  }

  Image {
    id: chosen
    visible: root.selected
    source: Cpp.path + "/image/card/chosen.png"
    anchors.centerIn: skinImg
    scale: 1.25
  }

  HoverHandler {
    id: hover
    enabled: root.selectable
    cursorShape: Qt.PointingHandCursor
  }

}