import QtQuick
import Fk

Item {
  id: root
  property int pileNum: 0
  property int roundNum: 0
  property int playedTime: 0
  visible: roundNum || pileNum

  function getTimeString(time) {
    let s = time % 60;
    s < 10 && (s = '0' + s);
    const m = (time - s) / 60;
    const h = (time - s - m * 60) / 3600;
    return h ? `${h}:${m}:${s}` : `${m}:${s}`;
  }

  Text {
    id: roundTxt
    anchors.right: parent.right
    text: Backend.translate("#currentRoundNum").arg(roundNum)
    color: "#F0E5DA"
    font.pixelSize: 18
    font.family: fontLibian.name
    style: Text.Outline
    styleColor: "#3D2D1C"
  }

  Text {
    id: timeTxt
    anchors.right: roundTxt.left
    anchors.rightMargin: 12
    color: "#F0E5DA"
    font.pixelSize: 18
    font.family: fontLibian.name
    style: Text.Outline
    styleColor: "#3D2D1C"
  }

  Timer {
    interval: 1000
    running: roomScene.isStarted
    repeat: true
    onTriggered: {
      playedTime++;
      timeTxt.text = getTimeString(playedTime);
    }
  }

  Image {
    id: deckImg
    anchors.top: timeTxt.bottom
    anchors.topMargin: 8
    anchors.right: parent.right
    anchors.rightMargin: 12
    source: SkinBank.CARD_DIR + "card-back"
    width: 32
    height: 42
  }

  Text {
    anchors.centerIn: deckImg
    font.family: fontLibian.name
    font.pixelSize: 32
    color: "white"
    style: Text.Outline
    text: pileNum.toString()
  }
}
