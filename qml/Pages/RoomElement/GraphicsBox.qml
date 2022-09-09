import QtQuick 2.15
import Qt5Compat.GraphicalEffects

Item {
  property alias title: titleItem
  signal accepted() //Read result
  signal finished() //Close the box

  id: root

  Rectangle {
    id: background
    anchors.fill: parent
    color: "#B0000000"
    radius: 5
    border.color: "#A6967A"
    border.width: 1
  }

  DropShadow {
    source: background
    anchors.fill: background
    color: "#B0000000"
    radius: 5
    //samples: 12
    spread: 0.2
    horizontalOffset: 5
    verticalOffset: 4
    transparentBorder: true
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
