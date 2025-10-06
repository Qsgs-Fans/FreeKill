import QtQuick
import Qt5Compat.GraphicalEffects

import Fk

Item {
  id: root
  width: childrenRect.width
  height: childrenRect.height

  property url source: ""
  property bool selected: false

  Image {
    id: skinImg
    source: root.source
    width: 120
    height: 170
    fillMode: Image.PreserveAspectCrop
    visible: false
  }

  Rectangle {
    id: skinMask
    anchors.fill: skinImg
    radius: 8
    color: "white"
    visible: false
  }
  

  OpacityMask {
    anchors.fill: skinImg
    source: skinImg
    maskSource: skinMask
  }

  Text {
    id: skinName
    text: Lua.tr(root.getSkinName())
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
    cursorShape: Qt.PointingHandCursor
  }

  function getSkinName() {
    const url = source.toString();
    const lastPart = url.slice(url.lastIndexOf("/") + 1);
    if (lastPart.lastIndexOf(".") !== -1) {
      return lastPart.slice(0, lastPart.lastIndexOf("."))
    }
    return lastPart
  }

}