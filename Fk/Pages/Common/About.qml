// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Widgets as W

W.PageBase {
  id: root

  ListModel {
    id: aboutModel
    ListElement { dest: "freekill" }
    ListElement { dest: "qt" }
    ListElement { dest: "lua" }
    ListElement { dest: "gplv3" }
    ListElement { dest: "sqlite" }
    ListElement { dest: "ossl" }
    ListElement { dest: "git2" }
  }

  ColumnLayout {
    anchors.fill: parent

    SwipeView {
      id: swipe
      Layout.fillWidth: true
      Layout.fillHeight: true
      currentIndex: indicator.currentIndex
      Repeater {
        model: aboutModel
        Item {
          Rectangle {
            anchors.centerIn: parent
            color: "#88EEEEEE"
            radius: 2
            width: root.width * 0.8
            height: root.height * 0.8

            Image {
              id: logo
              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              source: Cpp.path + "/image/logo/" + dest
              width: parent.width * 0.3
              fillMode: Image.PreserveAspectFit
            }

            Text {
              anchors.left: logo.right
              anchors.leftMargin: 16
              width: parent.width * 0.65
              text: Lua.tr("about_" + dest + "_description")
              wrapMode: Text.WordWrap
              textFormat: Text.MarkdownText
              font.pixelSize: 18
              onLinkActivated: (link) => Qt.openUrlExternally(link);
            }
          }
        }
      }
    }

    PageIndicator {
      id: indicator

      count: swipe.count
      currentIndex: swipe.currentIndex
      interactive: true

      Layout.alignment: Qt.AlignHCenter
    }
  }

  Button {
    text: Lua.tr("Quit")
    anchors.right: parent.right
    onClicked: {
      swipe.opacity = 0;
      App.quitPage();
    }
  }

}
