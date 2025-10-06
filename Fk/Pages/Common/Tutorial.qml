// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls

import Fk

Rectangle {
  id: root
  color: "#CCEEEEEE"
  property int total: 7

  SwipeView {
    id: view
    anchors.fill: parent

    Repeater {
      model: total
      Item {
        Text {
          text: qsTr("tutor_msg_" + (modelData + 1))
          font.pixelSize: 32
          wrapMode: Text.WordWrap
          anchors.centerIn: parent
          width: parent.width * 0.7
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.RichText
          onLinkActivated: Qt.openUrlExternally(link);
        }
      }
    }
  }

  /*
  PageIndicator {
    id: indicator

    count: total
    currentIndex: view.currentIndex

    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
  }
  */

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 20
    spacing: 8
    Text {
      text: (view.currentIndex + 1) + "/" + total
      font.pixelSize: 36
    }

    Button {
      text: qsTr("Skip")
      onClicked: App.quitPage();
    }

    Button {
      text: qsTr("Prev")
      enabled: view.currentIndex > 0
      onClicked: view.currentIndex--
    }

    Button {
      text: view.currentIndex + 1 == total ? qsTr("OK!") : qsTr("Next")
      enabled: view.currentIndex + 1 <= total
      onClicked: {
        if (view.currentIndex + 1 == total) {
          App.quitPage();
        } else {
          view.currentIndex++
        }
      }
    }
  }
}
