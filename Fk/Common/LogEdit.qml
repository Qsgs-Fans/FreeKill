// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
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
  delegate: TextEdit {
    id: textEdit

    text: logText
    width: root.width
    clip: true
    readOnly: true
    selectByKeyboard: true
    selectByMouse: false
    wrapMode: TextEdit.WrapAnywhere
    textFormat: TextEdit.RichText
    font.pixelSize: 16

    W.TapHandler {
      // acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.NoButton
      // gesturePolicy: TapHandler.WithinBounds
      onTapped: root.currentIndex = index;
    }
  }

  Button {
    text: luatr("Return to Bottom")
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
