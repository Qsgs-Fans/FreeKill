import QtQuick

import Fk

Rectangle {
  id: root
  color: '#f3ede5'
  radius: 2
  height: 0
  clip: true
  property string text: ""

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
      property: "height"
      to: 40
      duration: 100
    }
    NumberAnimation {
      duration: 2500
    }
    PropertyAnimation {
      target: root
      property: "height"
      to: 0
      duration: 150
    }
  }

  function show() {
    chatAnim.restart();
  }
}
