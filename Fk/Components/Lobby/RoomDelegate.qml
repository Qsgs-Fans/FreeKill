import QtQuick
import QtQuick.Controls

import Fk

Item {
  id: root

  // radius: 8
  height: 84 - 8
  width: 280 - 4 - 8

  required property int roomId
  required property string roomName
  required property string gameMode
  required property int playerNum
  required property int capacity
  required property bool hasPassword
  required property bool outdated

  required property var timer

  Rectangle {
    id: roomInfoRect
    width: childrenRect.width + 8
    height: childrenRect.height - 2 + 16
    radius: 6
    color: outdated ? "#CCCCCC" : "#D4E5F6"
    Text {
      x: 4; y: -1
      text: Lua.tr(gameMode) + ' #' + roomId
      font.strikeout: outdated
    }
  }

  Rectangle {
    id: roomMainRect
    anchors.top: roomInfoRect.bottom
    anchors.topMargin: -16
    radius: 6
    width: parent.width
    height: parent.height - roomInfoRect.height - anchors.topMargin
    color: outdated ? "#CCCCCC" : "#D4E5F6"

    Text {
      id: roomNameText
      horizontalAlignment: Text.AlignLeft
      width: parent.width - 16
      height: contentHeight
      maximumLineCount: 1
      wrapMode: Text.WrapAnywhere
      textFormat: Text.PlainText
      text: roomName
      // color: outdated ? "gray" : "black"
      font.pixelSize: 16
      font.strikeout: outdated
      // elide: Label.ElideRight
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.leftMargin: 8
      anchors.topMargin: 4
    }

    Image {
      source: Cpp.path + "/image/button/skill/locked.png"
      visible: hasPassword
      scale: 0.8
      anchors.top: parent.top
      anchors.topMargin: -28
      anchors.right: parent.right
      anchors.rightMargin: -14
    }

    Text {
      id: capacityText
      color: (playerNum == capacity) ? "red" : "black"
      text: playerNum + "/" + capacity
      font.pixelSize: 18
      font.bold: true
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 4
      anchors.left: parent.left
      anchors.leftMargin: 8
    }

    TextField {
      id: passwordEdit
      visible: hasPassword && !outdated
      width: parent.width - capacityText.width - enterButton.width - 4
      height: capacityText.height + 8
      anchors.left: capacityText.right
      anchors.leftMargin: 2
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 0
      onTextChanged: root.password = text;
    }

    ToolButton {
      id: enterButton
      text: (playerNum < capacity) ? Lua.tr("Enter") : Lua.tr("Observe")
      enabled: !outdated && !timer.running
      font.pixelSize: 16
      font.bold: true
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      //anchors.rightMargin: -4
      anchors.bottomMargin: -4
      onClicked: {
        timer.start();
        enterRoom(roomId, playerNum, capacity,
        hasPassword ? passwordEdit.text : "");
      }
    }
  }
}
