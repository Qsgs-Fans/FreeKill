import QtQuick
import QtQuick.Controls

import Fk
import Fk.Widgets as W

W.PageBase {
  id: root

  required property var gameContent
  readonly property real gameScale: 0.8
  property bool overlayOpened: false

  Rectangle {
    id: gameContentRect
    // color: "#60ED1E1E"
    color: "transparent"
    visible: false
    width: root.gameContent.width
    height: root.gameContent.height
    x: root.gameContent.x
    y: root.gameContent.y
    scale: root.gameContent.scale

    W.TapHandler {
      onTapped: root.closeOverlay();
    }
  }

  Button {
    id: menuButton
    anchors.top: parent.top
    anchors.topMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: 12
    text: Lua.tr("Menu")
    visible: !root.overlayOpened
    onClicked: {
      if (root.overlayOpened){
        root.closeOverlay();
      } else {
        root.openOverlay();
      }
    }
  }

  Shortcut {
    sequence: "Escape"
    onActivated: menuButton.clicked();
  }

  function openOverlay() {
    gameContent.scale = root.gameScale;
    // 左右各留20px
    const scale = (1 - gameScale) / 2;
    gameContent.x = 40 - gameContent.width * scale;
    // gameContent.y = gameContent.height * scale - 20;

    gameContentRect.visible = true;
    root.overlayOpened = true;
  }

  function closeOverlay() {
    gameContent.scale = 1;
    gameContent.x = 0;
    gameContent.y = 0;

    gameContentRect.visible = false;
    root.overlayOpened = false;
  }
}
