import QtQuick
import QtQuick.Controls

TextField {
  id: root

  property string title
  property alias value: root.text

  placeholderText: title

  Rectangle {
    anchors.fill: parent
    z: -1
    implicitHeight: 60
    //radius: 12
    color: "#FEFFFE"

    Rectangle {
      width: parent.width; height: parent.height
      x: 2; y: 2; z: -1
      color: "#3F000000"
    }
  }
}
