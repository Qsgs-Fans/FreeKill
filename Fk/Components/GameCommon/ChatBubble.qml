import QtQuick

import Fk

Rectangle {
  id: root
  color: "#F2ECD7"
  radius: 4
  opacity: 0
  height: childrenRect.height + 8
  property string text: ""
  visible: false

  Text {
    width: parent.width - 8
    x: 4
    y: 4
    text: parent.text
    wrapMode: Text.WrapAnywhere
    font.family: Config.libianName
    font.pixelSize: 15
  }

  SequentialAnimation {
    id: chatAnim
    PropertyAnimation {
      target: root
      property: "opacity"
      to: 0.9
      duration: 200
    }
    NumberAnimation {
      duration: 2500
    }
    PropertyAnimation {
      target: root
      property: "opacity"
      to: 0
      duration: 150
    }
    onFinished: root.visible = false;
  }

  function show() {
    chatAnim.restart();
  }
}
