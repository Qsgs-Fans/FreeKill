// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk

Rectangle {
  id: splash
  color: "#EEEEEE"
  z: 100

  property bool loading: true
  property alias animationRunning: animation.running

  signal disappearing
  signal disappeared

  Grid {
    id: main
    anchors.centerIn: parent
    rows: splash.width >= splash.height ? 1 : 2
    columns: splash.width >= splash.height ? 2 : 1
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    spacing: 25

    Image {
      id: logo
      source: Cpp.path + "/image/icon.png"
      width: 96
      height: width
      opacity: 0
    }

    Column {
      spacing: 6

      Text {
        id: fktext
        text: qsTr("FreeKill")
        // color: "#ffffff"
        font.pixelSize: 40
        opacity: 0
      }

      RowLayout {
        width: parent.width
        spacing: 8

        Text {
          id: free
          text: qsTr("Free")
          // color: "#ffffff"
          font.pixelSize: 20
          opacity: 0
          Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        }

        Text {
          id: open
          text: qsTr("Open")
          // color: "#ffffff"
          font.pixelSize: 20
          opacity: 0
          Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        }

        Text {
          id: flexible
          text: qsTr("Flexible")
          // color: "#ffffff"
          font.pixelSize: 20
          opacity: 0
          Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        }
      }
    }
  }

  Text {
    id: text
    text: qsTr("Press Any Key...")
    // color: "#ffffff"
    opacity: 0
    font.pointSize: 15
    horizontalAlignment: Text.AlignHCenter
    anchors.horizontalCenter: parent.horizontalCenter
    y: (main.y + main.height + parent.height - height) / 2
    SequentialAnimation on opacity {
      id: textAni
      running: false
      loops: Animation.Infinite
      NumberAnimation {
        from: 0; to: 1; duration: 1600
        easing.type: Easing.InOutQuad
      }
      NumberAnimation {
        from: 1; to: 0; duration: 1600
        easing.type: Easing.InOutQuad
      }
    }
  }

  SequentialAnimation {
    id: animation
    running: true

    PauseAnimation {
      duration: 400
    }

    ParallelAnimation {
      NumberAnimation {
        target: fktext
        property: "opacity"
        duration: 500
        easing.type: Easing.InOutQuad
        to: 1
      }

      NumberAnimation {
        target: logo
        property: "opacity"
        duration: 500
        easing.type: Easing.InOutQuad
        to: 1
      }
    }

    NumberAnimation {
      target: free
      property: "opacity"
      duration: 400
      easing.type: Easing.InOutQuad
      to: 1
    }

    NumberAnimation {
      target: open
      property: "opacity"
      duration: 400
      easing.type: Easing.InOutQuad
      to: 1
    }

    NumberAnimation {
      target: flexible
      property: "opacity"
      duration: 400
      easing.type: Easing.InOutQuad
      to: 1
    }


    ScriptAction { script: textAni.start(); }

    PropertyAction { target: splash; property: "loading"; value: false }
  }

  /**
  Text {
    text: "常用联机IP：175.178.66.93\n新月杀联机交流群：531553435"
    font.pixelSize: 20
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 20
    anchors.right: parent.right
    anchors.rightMargin: 20
    horizontalAlignment: Text.AlignRight
  }
  **/

  //--------------------Disappear--------------
  Behavior on opacity {
    SequentialAnimation {
      NumberAnimation { duration: 1200; easing.type: Easing.InOutQuad }
      ScriptAction { script: disappeared() }
    }
  }
  MouseArea {
    acceptedButtons: Qt.AllButtons
    anchors.fill: parent
    onClicked: {
      disappear();
    }
  }

  Keys.onPressed: {
    disappear();
    event.accepted = true
  }

  NumberAnimation {
    id: logoMover
    target: logo
    property: "x"
    to: -splash.width
    duration: 1000
    easing.type: Easing.InOutQuad
  }

  function disappear() {
    disappearing();
    logoMover.start();
    opacity = 0;
  }
}
