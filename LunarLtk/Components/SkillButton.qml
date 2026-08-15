// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import Fk
import Fk.Widgets as W

import LunarLtk

Item {
  id: root

  required property SkillModel dataModel

  width: (dataModel.isActive || dataModel.isPrelight) ? Math.max(80, skillTxt.width + 8) : skillTxt.width
  height: (dataModel.isActive || dataModel.isPrelight) ? 36 : 24

  Image {
    x: -13 - 120 * 0.166
    y: -6 - 55 * 0.166
    scale: 0.66
    source: {
      if (root.dataModel.isActive) {
        let ret = Cpp.path + "/image/button/skill/active/";
        const enabled = root.dataModel.enabled;
        let suffix = enabled ? (root.dataModel.selected ? "pressed" : "normal") : "disabled";
        if (enabled && root.dataModel.origName.endsWith("&")) {
          suffix += "-attach";
        }
        return ret + suffix;
      } else if (root.dataModel.isPrelight) {
        let ret = Cpp.path + "/image/button/skill/prelight/";
        const enabled = root.dataModel.enabled;
        let suffix = enabled ? (root.dataModel.selected ? "pressed" : "normal") : "disabled";
        return ret + suffix;
      }
      return "";
    }
  }

  Image {
    visible: root.dataModel.isPrelight
    source: Cpp.path + "/image/button/skill/" +
      (root.dataModel.prelighted ? "prelight.png" : "unprelight.png")
    transformOrigin: Item.TopLeft
    x: -10
    scale: 0.7
  }

  Text {
    id: skillTxt
    anchors.centerIn: parent
    topPadding: 5
    font.family: Config.li2Name
    font.pixelSize: Math.max(26 - text.length, 18)
    visible: false
    font.bold: true
    text: root.dataModel.name
  }

  Glow {
    source: skillTxt
    anchors.fill: skillTxt
    color: "black"
    spread: 0.3
    radius: 5
  }

  LinearGradient  {
    anchors.fill: skillTxt
    source: skillTxt
    gradient: Gradient {
      GradientStop {
        position: 0
        color: root.dataModel.nullified ? "#CCC8C4" : "#FEF7C2"
      }

      GradientStop {
        position: 0.8
        color: root.dataModel.nullified ? "#A09691" : "#D2AD4A"
      }

      GradientStop {
        position: 1
        color: root.dataModel.nullified ? "#787173" : "#BE9878"
      }
    }
  }

  Image {
    source: Cpp.path + "/image/button/skill/locked.png"
    scale: 0.8
    z: 2
    visible: root.dataModel.nullified
    opacity: 0.8
    anchors.centerIn: parent
  }

  Item {
    width: 12
    height: 12
    visible: root.dataModel.times > -1
    anchors.right: parent.right
    anchors.rightMargin: root.dataModel.isActive ? 5 : -5
    anchors.top: parent.top
    anchors.topMargin: root.dataModel.isActive ? 5 : 0

    Rectangle {
      width: Math.max(15, 1.4 * count.contentWidth)
      height: 15
      radius: width * 0.5
      x: (parent.width - width) / 2
      y: -1.5
      color: "transparent"
      border.color: root.dataModel.nullified ? "#A09691" : "#D2AD4A"
      border.width: 1.1
    }

    Text {
      id: count
      anchors.centerIn: parent
      font.pixelSize: 16
      font.family: Config.libianName
      font.bold: true
      text: root.dataModel.times
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
          color: root.dataModel.nullified ? "#CCC8C4" : "#FEF7C2"
        }

        GradientStop {
          position: 0.8
          color: root.dataModel.nullified ? "#A09691" : "#D2AD4A"
        }

        GradientStop {
          position: 1
          color: root.dataModel.nullified ? "#787173" : "#BE9878"
        }
      }
    }
  }

  W.TapHandler {
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.NoButton
    onTapped: (p, btn) => {
      if ((btn === Qt.LeftButton || btn === Qt.NoButton) && (root.dataModel.isActive || root.dataModel.isPrelight) && root.dataModel.enabled) {
        root.dataModel.selected = !root.dataModel.selected;
      } else if (btn === Qt.RightButton) {
        skillDetail.visible = true;
      }
    }

    onLongPressed: {
      skillDetail.visible = true;
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
      text: "<b>" + Lua.tr(root.dataModel.origName) + "</b>: " + Lua.evaluate(`Fk:getDescription('${root.dataModel.origName}', nil, Self)`)
      font.pixelSize: 20
      wrapMode: Text.WordWrap
      textFormat: TextEdit.RichText
      color: "#E4D5A0"
    }

    background: Rectangle {
      color: "#CC2E2C27"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }
  }
}
