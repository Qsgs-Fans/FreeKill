import QtQuick

Item {
  property alias title: titleItem
  signal accepted() //Read result
  signal finished() //Close the box

  id: root

  Rectangle {
    id: background
    anchors.fill: parent
    color: "#020302"
    opacity: 0.8
    radius: 5
    border.color: "#A6967A"
    border.width: 1
  }

  Text {
    id: titleItem
    color: "#E4D5A0"
    font.pixelSize: 18
    horizontalAlignment: Text.AlignHCenter
    anchors.top: parent.top
    anchors.topMargin: 4
    anchors.horizontalCenter: parent.horizontalCenter
  }

  MouseArea {
    anchors.fill: parent
    drag.target: parent
    drag.axis: Drag.XAndYAxis
  }

  function close()
  {
    accepted();
    finished();
  }
}
