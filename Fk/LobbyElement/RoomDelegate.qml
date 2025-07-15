import QtQuick
import QtQuick.Controls
import Fk.Widgets as W

Item {
  id: roomDelegate

  Rectangle {
    // radius: 8
    height: 124 - 8
    width: 300 - 8
    color: outdated ? "#E2E2E2" : "#DDDDDDDD"

    Text {
      id: roomNameText
      horizontalAlignment: Text.AlignLeft
      width: parent.width - 16
      height: contentHeight
      maximumLineCount: 2
      wrapMode: Text.WrapAnywhere
      textFormat: Text.PlainText
      text: roomName
      // color: outdated ? "gray" : "black"
      font.pixelSize: 16
      font.strikeout: outdated
      // elide: Label.ElideRight
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.margins: 8
    }

    Text {
      id: roomIdText
      text: luatr(gameMode) + ' #' + roomId
      font.strikeout: outdated
      anchors.top: roomNameText.bottom
      anchors.left: roomNameText.left
    }

    Image {
      source: AppPath + "/image/button/skill/locked.png"
      visible: hasPassword
      scale: 0.8
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.margins: -4
    }

    Text {
      color: (playerNum == capacity) ? "red" : "black"
      text: playerNum + "/" + capacity
      font.pixelSize: 18
      font.bold: true
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 8
      anchors.right: parent.right
      anchors.rightMargin: 8
    }

    W.TapHandler {
      gesturePolicy: TapHandler.WithinBounds
      enabled: !opTimer.running && !outdated

      onTapped: {
        lobby_dialog.sourceComponent = roomDetailDialog;
        lobby_dialog.item.roomData = {
          roomId, roomName, gameMode, playerNum, capacity,
          hasPassword, outdated,
        };
        lobby_dialog.item.roomConfig = config.roomConfigCache?.[config.serverAddr]?.[roomId]
        lobby_drawer.open();
      }
    }
  }
}

