import QtQuick
import Fk

Image {
  id: root
  property int value: 0
  width: 20
  height: 21
  visible: (value > 0)
  source: SkinBank.MAGATAMA_DIR + "shield"

  Text {
    text: value
    anchors.horizontalCenter: parent.horizontalCenter
    y: -2
    font.family: fontLibian.name
    font.pixelSize: 20
    font.bold: true
    color: "white"
    style: Text.Outline
  }
}
