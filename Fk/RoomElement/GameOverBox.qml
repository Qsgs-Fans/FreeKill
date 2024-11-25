// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk.Pages

GraphicsBox {
  property string winner: ""

  id: root
  title.text: luatr("$GameOver")
  width: Math.max(140, body.width + 20)
  height: body.height + title.height + 20

  Column {
    id: body
    x: 10
    y: title.height + 5
    spacing: 10

    Text {
      text: winner !== "" ? luatr("$Winner").arg(luatr(winner))
                          : luatr("$NoWinner")
      color: "#E4D5A0"
    }

    MetroButton {
      text: luatr("Back To Room")
      anchors.horizontalCenter: parent.horizontalCenter
      visible: !config.observing

      onClicked: {
        roomScene.resetToInit();
        finished();
      }
    }

    MetroButton {
      text: luatr("Back To Lobby")
      anchors.horizontalCenter: parent.horizontalCenter

      onClicked: {
        if (config.replaying) {
          mainStack.pop();
          Backend.controlReplayer("shutdown");
        } else {
          ClientInstance.notifyServer("QuitRoom", "[]");
        }
      }
    }

    MetroButton {
      id: repBtn
      text: luatr("Save Replay")
      anchors.horizontalCenter: parent.horizontalCenter
      visible: config.observing && !config.replaying

      onClicked: {
        repBtn.visible = false;
        lcall("SaveRecord");
        toast.show("OK.");
      }
    }
  }
}
