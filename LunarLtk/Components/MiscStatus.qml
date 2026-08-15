import QtQuick
import Fk
import LunarLtk

Item {
  id: root
  required property RoomModel dataModel
  visible: dataModel.roundCount || dataModel.drawPileNum

  Text {
    id: roundTxt
    anchors.right: parent.right
    text: Lua.tr("#currentRoundNum").arg(root.dataModel.roundCount)
    color: "#F0E5DA"
    font.pixelSize: 18
    font.family: Config.libianName
    style: Text.Outline
    styleColor: "#3D2D1C"
  }

  Text {
    id: timeTxt
    anchors.right: roundTxt.left
    anchors.rightMargin: 12
    color: "#F0E5DA"
    font.pixelSize: 18
    font.family: Config.libianName
    style: Text.Outline
    styleColor: "#3D2D1C"
    text: root.dataModel.getTimeString(root.dataModel.playedTime);
  }

  // FIXME: 杀了这个timer 在刷状态技那里改Model的数据才对
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      root.dataModel.playedTime++;
    }
  }

  Image {
    id: deckImg
    anchors.top: timeTxt.bottom
    anchors.topMargin: 8
    anchors.right: parent.right
    anchors.rightMargin: 12
    source: SkinBank.searchBuiltinPic("/image/card/", "card-back")
    width: 32
    height: 42
  }

  Text {
    anchors.centerIn: deckImg
    font.family: Config.libianName
    font.pixelSize: 32
    color: "white"
    style: Text.Outline
    text: root.dataModel.drawPileNum.toString()
  }
}
