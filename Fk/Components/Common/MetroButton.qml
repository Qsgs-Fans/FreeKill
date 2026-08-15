// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects

import Fk.Widgets as W

Item {
  property bool enabled: true
  property alias title: title
  property alias text: title.text
  property alias textColor: title.color
  property alias textFont: title.font
  property alias backgroundColor: bg.color
  property alias border: bg.border
  property alias icon: icon
  property alias iconSource: icon.source
  property int padding: 0
  property bool hovered: false
  property bool checked: false

  signal clicked
  signal rightClicked

  id: button
  width: icon.width + title.implicitWidth + padding * 2 + (icon.visible ? 4 : 0) + 16
  height: Math.max(icon.height, title.implicitHeight) + padding * 2 + 16

  // 背景阴影
  RectangularGlow {
    anchors.fill: bg
    anchors.topMargin: 1
    anchors.leftMargin: 1
    anchors.rightMargin: 1
    anchors.bottomMargin: 1
    glowRadius: 4
    spread: 0.2
    color: bg.color
    opacity: mouse.containsPress ? 0.0 : (hover.hovered ? 0.6 : 0.3)
    Behavior on opacity { NumberAnimation { duration: 150 } }
    visible: enabled
  }

  // 主背景
  Rectangle {
    id: bg
    anchors.centerIn: parent
    width: parent.width - parent.padding * 2
    height: parent.height - parent.padding * 2
    radius: 6
    color: checked ? "#3D2E2E" : (hover.hovered ? "#5C3D3D" : "#2A1F1F")
    border.width: checked ? 2 : 1
    border.color: checked ? "#D4A84B" : (hover.hovered ? "#E8C56A" : "#6B4F3A")
    opacity: enabled ? 1.0 : 0.35

    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
    Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }

    // 按下时的内凹效果
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: "transparent"
      border.width: 0
      opacity: mouse.containsPress ? 0.15 : 0.0
      Behavior on opacity { NumberAnimation { duration: 80 } }
    }
  }

  // 顶部高光线（玻璃质感）
  Rectangle {
    anchors.top: bg.top
    anchors.left: bg.left
    anchors.right: bg.right
    height: bg.height * 0.45
    radius: bg.radius
    color: "transparent"
    clip: true

    Rectangle {
      anchors.fill: parent
      radius: bg.radius
      color: "#D4A84B"
      opacity: hover.hovered && enabled ? 0.12 : 0.06
      Behavior on opacity { NumberAnimation { duration: 150 } }
    }
  }

  // 内容行
  Row {
    anchors.centerIn: bg
    spacing: 6

    Image {
      id: icon
      anchors.verticalCenter: parent.verticalCenter
      fillMode: Image.PreserveAspectFit
      visible: source.toString() !== ""
      sourceSize: Qt.size(20, 20)
    }

    Text {
      id: title
      font.pixelSize: 18
      font.weight: Font.Medium
      anchors.verticalCenter: parent.verticalCenter
      text: ""
      color: checked ? "#F0D68A" : (hover.hovered ? "#FFF5D6" : "#E8D5B0")
      Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
    }
  }

  // 点击波纹效果
  Rectangle {
    id: ripple
    width: 0
    height: 0
    radius: width / 2
    color: "white"
    opacity: 0.0
    anchors.centerIn: parent
  }

  states: [
    State {
      name: "disabled"; when: !enabled
      PropertyChanges { target: button; opacity: 0.4 }
    }
  ]

  W.TapHandler {
    id: mouse
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.NoButton
    gesturePolicy: TapHandler.WithinBounds

    onTapped: (p, btn) => {
      if (parent.enabled) {
        if (btn === Qt.LeftButton || btn === Qt.NoButton) {
          parent.clicked();
        } else if (btn === Qt.RightButton) {
          parent.rightClicked();
        }
      }
    }

    onLongPressed: {
      parent.rightClicked();
    }
  }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
    onHoveredChanged: {
      if (hovered) {
        button.hovered = true;
      } else {
        button.hovered = false;
      }
    }
  }
}
