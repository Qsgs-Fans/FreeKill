import QtQuick
import Fk

Image {
  id: root
  property int value: 0
  width: 15
  height: 16
  visible: (value > 0)
  source: SkinBank.magatamaDir + "shield"

  Text {
    text: value
    anchors.horizontalCenter: parent.horizontalCenter
    y: -2
    font.family: Config.libianName
    font.pixelSize: 15
    font.bold: true
    color: "white"
    style: Text.Outline
  }
}
