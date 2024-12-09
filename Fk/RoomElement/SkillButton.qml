// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Controls

Item {
  id: root
  property alias skill: skill.text
  property string type: "active"
  property string orig: ""
  property bool pressed: false
  property bool prelighted: false
  property bool locked: false
  property int times: -1

  onEnabledChanged: {
    if (!enabled)
      pressed = false;
  }

  width: type !== "notactive" ? Math.max(80, skill.width + 8) : skill.width + (root.times > -1 ? 45 : 0)
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
    font.family: fontLi2.name
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
    anchors.rightMargin: 5
    anchors.top: parent.top
    anchors.topMargin: 5

    Rectangle {
      width: Math.max(15, 1.4 * count.contentWidth)
      height: 15
      radius: width * 0.5
      x: (parent.width - width) / 2
      y: -1.5
      color: "transparent"
      border.color: "#D2AD4A"
      border.width: 1.1
    }

    Text {
      id: count
      anchors.centerIn: parent
      font.pixelSize: 16
      font.family: fontLibian.name
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

  TapHandler {
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.NoButton
    onTapped: (p, btn) => {
      if ((btn === Qt.LeftButton || btn === Qt.NoButton) && root.type !== "notactive" && root.enabled) {
        parent.pressed = !parent.pressed;
      } else if (btn === Qt.RightButton) {
        skillDetail.open();
      }
    }

    onLongPressed: {
      skillDetail.open();
    }
  }

  Popup {
    id: skillDetail
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    property string text: ""
    width: Math.min(contentWidth, realMainWin.width * 0.4)
    height: Math.min(contentHeight + 24, realMainWin.height * 0.9)
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 12
    background: Rectangle {
      color: "#EEEEEEEE"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }
    contentItem: Text {
      text: "<b>" + luatr(orig) + "</b>: " + luatr(":" + orig)
      font.pixelSize: 20
      wrapMode: Text.WordWrap
      textFormat: TextEdit.RichText

      TapHandler {
        onTapped: skillDetail.close();
      }
    }
  }
}
