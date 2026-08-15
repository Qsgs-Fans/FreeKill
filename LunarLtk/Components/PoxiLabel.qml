import QtQuick
import Fk

// 见于各大弹窗，左侧的那个竖排小label
// 实在看不下去，封装一下

Rectangle {
  property string text

  color: "#6B5D42"
  implicitWidth: 20
  implicitHeight: 100
  radius: 5

  Text {
    anchors.fill: parent
    width: 20
    height: 100
    text: parent.text
    color: "white"
    font.family: Config.libianName
    font.pixelSize: 18
    style: Text.Outline
    wrapMode: Text.WordWrap
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
  }
}
