// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls

import Fk
import Fk.Widgets as W

ListView {
  id: root

  clip: true

  highlight: Rectangle { color: "#EEEEEE"; radius: 5 }
  highlightMoveDuration: 500

  ScrollBar.vertical: ScrollBar {
    parent: root.parent
    anchors.top: root.top
    anchors.right: root.right
    anchors.bottom: root.bottom
  }

  model: ListModel { id: logModel }
  delegate: Rectangle {
    width: root.width
    height: childrenRect.height
    color: "transparent"

    W.TapHandler {
      onTapped: {
        root.currentIndex = index;
      }
    }

    TextEdit {
      z: -1 // 挡住我taphandler了
      text: logText
      width: parent.width
      clip: true
      readOnly: true
      selectByKeyboard: true
      selectByMouse: false
      wrapMode: TextEdit.WrapAnywhere
      textFormat: TextEdit.RichText
      font.pixelSize: 16
    }
  }

  Button {
    text: Lua.tr("Return to Bottom")
    visible: root.currentIndex !== logModel.count - 1
    onClicked: root.currentIndex = logModel.count - 1;
  }

  function clear() {
    logModel.clear();
    root.currentIndex = 0;
  }

  function append(data) {
    const autoScroll = root.currentIndex === logModel.count - 1;
    logModel.append(data);
    if (autoScroll) {
      root.currentIndex = logModel.count - 1;
    }
  }
}
