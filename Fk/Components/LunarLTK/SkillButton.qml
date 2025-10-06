// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import Fk
import Fk.Widgets as W

Item {
  id: root
  property alias skill: skill.text
  property string type: "active"
  property string orig: ""
  property bool pressed: false
  property bool doubleTapped: false
  property bool prelighted: false
  property bool locked: false
  property int times: -1

  onEnabledChanged: {
    if (!enabled)
      pressed = false;
  }

  width: type !== "notactive" ? Math.max(80, skill.width + 8) : skill.width
  height: type !== "notactive" ? 36 : 24

  Image {
    x: -13 - 120 * 0.166
    y: -6 - 55 * 0.166
    scale: 0.66
    source: {
      if (type === "notactive") {
        return "";
      }
      let ret = AppPath + "/image/button/skill/" + type + "/";
      let suffix = enabled ? (pressed ? "pressed" : "normal") : "disabled";
      if (enabled && type === "active" && orig.endsWith("&")) {
        suffix += "-attach";
      }
      return ret + suffix;
    }
  }

  Image {
    visible: type === "prelight"
    source: AppPath + "/image/button/skill/" +
      (prelighted ? "prelight.png" : "unprelight.png")
    transformOrigin: Item.TopLeft
    x: -10
    scale: 0.7
  }

  Text {
    anchors.centerIn: parent
    topPadding: 5
    id: skill
    font.family: Config.li2Name
    font.pixelSize: Math.max(26 - text.length, 18)
    visible: false
    font.bold: true
  }

  Glow {
    id: glowItem
    source: skill
    anchors.fill: skill
    color: "black"
    spread: 0.3
    radius: 5
  }

  LinearGradient  {
    anchors.fill: skill
    source: skill
    gradient: Gradient {
      GradientStop {
        position: 0
        color: root.locked ? "#CCC8C4" : "#FEF7C2"
      }

      GradientStop {
        position: 0.8
        color: root.locked ? "#A09691" : "#D2AD4A"
      }

      GradientStop {
        position: 1
        color: root.locked ? "#787173" : "#BE9878"
      }
    }
  }

  Image {
    source: AppPath + "/image/button/skill/locked.png"
    scale: 0.8
    z: 2
    visible: root.locked
    opacity: 0.8
    anchors.centerIn: parent
  }

  Item {
    width: 12
    height: 12
    visible: root.times > -1
    anchors.right: parent.right
    anchors.rightMargin: root.type !== "notactive" ? 5 : -5
    anchors.top: parent.top
    anchors.topMargin: root.type !== "notactive" ? 5 : 0

    Rectangle {
      width: Math.max(15, 1.4 * count.contentWidth)
      height: 15
      radius: width * 0.5
      x: (parent.width - width) / 2
      y: -1.5
      color: "transparent"
      border.color: root.locked ? "#A09691" : "#D2AD4A"
      border.width: 1.1
    }

    Text {
      id: count
      anchors.centerIn: parent
      font.pixelSize: 16
      font.family: Config.libianName
      font.bold: true
      text: root.times
      z: 1.5
    }

    Glow {
      source: count
      anchors.fill: count
      color: "black"
      spread: 0.3
      radius: 5
    }

    LinearGradient {
      anchors.fill: count
      z: 3
      source: count
      gradient: Gradient {
        GradientStop {
          position: 0
          color: root.locked ? "#CCC8C4" : "#FEF7C2"
        }

        GradientStop {
          position: 0.8
          color: root.locked ? "#A09691" : "#D2AD4A"
        }

        GradientStop {
          position: 1
          color: root.locked ? "#787173" : "#BE9878"
        }
      }
    }
  }

  W.TapHandler {
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.NoButton
    onTapped: (p, btn) => {
      if ((btn === Qt.LeftButton || btn === Qt.NoButton) && root.type !== "notactive" && root.enabled) {
        parent.pressed = !parent.pressed;
      } else if (btn === Qt.RightButton) {
        skillDetail.visible = true;
      }
    }

    onLongPressed: {
      skillDetail.visible = true;
    }

    onDoubleTapped: (p, btn) => {
      if (btn === Qt.LeftButton || btn === Qt.NoButton) {
        parent.doubleTapped = true;
      }
    }
  }

  ToolTip {
    id: skillDetail
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: Math.min(contentWidth, Config.winWidth * 0.4)
    height: Math.min(contentHeight + 24, Config.winHeight * 0.9)
    visible: false

    contentItem: Text{
      text: "<b>" + Lua.tr(orig) + "</b>: " + Lua.tr(":" + orig)
      font.pixelSize: 20
      wrapMode: Text.WordWrap
      textFormat: TextEdit.RichText
      color: "#E4D5A0"
    }

    background: Rectangle { // same as cheatDrawer
      color: "#CC2E2C27"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }
  }
}
