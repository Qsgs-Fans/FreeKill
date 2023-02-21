import QtQuick

Item {
  Text {
    id: txt
    anchors.centerIn: parent
    text: "Hello, world!"
    font.pixelSize: 64
  }

  PropertyAnimation {
    target: txt
    property: "opacity"
    to: 0.3
    duration: 2000
    running: true
    onFinished: {
      roomScene.bigAnim.source = "";
    }
  }
}
