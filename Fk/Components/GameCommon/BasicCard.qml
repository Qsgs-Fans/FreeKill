import QtQuick
import Qt5Compat.GraphicalEffects

import Fk

BasicItem {
  id: root

  property bool known: true     // if false it only show a card back

  property url cardFrontSource
  property url cardBackSource

  property string footnote: ""  // footnote, e.g. "A use card to B"
  property bool footnoteVisible: false
  property alias footnoteItem: footnoteItem

  property alias chosenInBox: chosen.visible

  property alias glow: glowItem

  onHoverChanged: (hover) => {
    if (hover) {
      glowItem.opacity = 1;
    } else {
      glowItem.opacity = 0;
    }
  }

  Image {
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
    source: parent.known ? parent.cardFrontSource : parent.cardBackSource
  }

  Text {
    id: footnoteItem
    text: parent.footnote
    x: 0
    y: parent.height - height - 10
    width: root.width - x * 2
    color: "#E4D5A0"
    visible: parent.footnoteVisible
    style: Text.Outline
    wrapMode: Text.WrapAnywhere
    horizontalAlignment: Text.AlignHCenter
    font.family: Config.libianName
    font.pixelSize: 14
  }

  Image {
    id: chosen
    visible: false
    source: SkinBank.cardDir + "chosen"
    anchors.horizontalCenter: parent.horizontalCenter
    y: 90
    scale: 1.25
    z: 1
  }

  Rectangle {
    visible: !root.selectable
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.5)
    opacity: 0.7
    z: 2
  }

  RectangularGlow {
    id: glowItem
    anchors.fill: parent
    glowRadius: 8
    spread: 0
    color: "#88FFFFFF"
    cornerRadius: 8
    opacity: 0
    z: -100

    Behavior on opacity {
      NumberAnimation { duration: 200 }
    }
  }
}
