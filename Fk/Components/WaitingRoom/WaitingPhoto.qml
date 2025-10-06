import QtQuick

import Fk
import Fk.Components.LunarLTK

PhotoBase {
  id: root

  property bool isOwner: false
  property bool ready: false

  property int winGame: 0
  property int runGame: 0
  property int totalGame: 0

  photoMask.x: winRateRect.x
  photoMask.width: winRateRect.width

  Image {
    anchors.bottom: winRateRect.top
    anchors.right: parent.right
    anchors.bottomMargin: -6
    anchors.rightMargin: 4
    source: SkinBank.photoDir +
            (isOwner ? "owner" : (ready ? "ready" : "notready"))
    visible: screenName != ""
    transformOrigin: Item.BottomRight
    scale: 0.75
  }

  Rectangle {
    id: winRateRect
    width: 122; x: 4
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 4
    height: childrenRect.height + 6
    color: "#CC3C3229"
    radius: 6
    border.color: "white"
    border.width: 1
    visible: screenName != "" && !roomScene.isStarted

    Text {
      y: 3
      anchors.horizontalCenter: parent.horizontalCenter
      font.pixelSize: 15
      font.family: Config.libianName
      color: (totalGame > 0 && runGame / totalGame > 0.2) ? "red" : "white"
      style: Text.Outline
      text: {
        const totalTime = Lua.call("GetPlayerGameData", root.playerid)[3];
        let timeStr
        const h = (totalTime / 3600).toFixed(2);
        const m = Math.floor(totalTime / 60);
        if (m < 100) {
          timeStr = `${m} min`;
        } else {
          timeStr = `${h} h`;
        }

        let ret = `时长: ${timeStr}\n`

        if (totalGame === 0) {
          ret += Lua.tr("Newbie");
        } else {
          const winRate = (winGame / totalGame) * 100;
          const runRate = (runGame / totalGame) * 100;
          ret += Lua.tr("Win=%1\nRun=%2\nTotal=%3")
            .arg(winRate.toFixed(2))
            .arg(runRate.toFixed(2))
            .arg(totalGame);
        }
        return ret
      }
    }
  }
}
