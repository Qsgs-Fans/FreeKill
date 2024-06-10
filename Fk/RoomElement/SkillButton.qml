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
        color: "#FEF7C2"
      }

      GradientStop {
        position: 0.5
        color: "#D2AD4A"
      }

      GradientStop {
        position: 1
        color: "#BE9878"
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
