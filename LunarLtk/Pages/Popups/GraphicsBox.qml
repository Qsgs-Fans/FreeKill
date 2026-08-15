// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

Item {
  id: root

  property alias title: titleItem
  property alias background: background
  signal accepted() //Read result
  signal finished() //Close the box

  signal shown() // 对话框刚刚展示时触发的信号

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

  DragHandler {
    enabled: background.visible
    grabPermissions: PointHandler.TakeOverForbidden
    xAxis.enabled: true
    yAxis.enabled: true
  }

  // transform: Rotation {
  //   id: rotate
  //   axis { x: 1; y: 0; z: 0 }
  //   angle: 0
  //   origin { x: root.width / 2; y: root.height / 2 }
  // }

  property Animation showAnim//: ParallelAnimation {
    // PropertyAnimation {
    //   target: root
    //   property: "scale"
    //   from: 0.7
    //   to: 1
    //   duration: 120
    // }

    // PropertyAnimation {
    //   target: rotate
    //   property: "angle"
    //   from: 45
    //   to: 0
    //   duration: 200
    // }
  // }

  property Animation outAnim// : ParallelAnimation {
    // PropertyAnimation {
    //   target: root
    //   property: "scale"
    //   from: 1
    //   to: 0.7
    //   duration: 120
    // }

    // PropertyAnimation {
    //   target: rotate
    //   property: "angle"
    //   from: 0
    //   to: 45
    //   duration: 200
    // }
  // }

  function close()
  {
    accepted();
    finished();
  }
}
