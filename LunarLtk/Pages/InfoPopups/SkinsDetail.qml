// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Widgets as W
import Fk.Components.Common

import LunarLtk.Components
import LunarLtk

pragma ComponentBehavior: Bound

Item {
  id: root
  property var skins: []
  property var deputy_skins: []
  property string orig_general: ""
  property string orig_deputy: ""
  property string selected_skin: ""
  property string selected_deputy_skin: ""

  signal finish()

  anchors.fill: parent

  Item {
    id: title
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    height: childrenRect.height + 4

    GlowText {
      id: pileName
      text: "皮肤选择"
      horizontalAlignment: Text.AlignHCenter
      width: parent.width
      font.family: "LiSu"
      color: "#E4D5A0"
      font.pixelSize: 30
      font.weight: Font.Medium
      glow.color: "black"
      glow.spread: 0.3
      glow.radius: 5
    }

    LinearGradient  {
      anchors.fill: pileName
      source: pileName
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
  }

  Rectangle {
    id: skinTitle
    anchors.left: root.left
    height: 170
    anchors.bottom: skin.bottom
    anchors.bottomMargin: 17
    width: 80
    radius: 5
    color: '#79000000'
    visible: skin.visible

    Column {
      anchors.centerIn: parent
      Repeater {
        model: Lua.tr(root.orig_general).length
        Text {
          required property int index
          text: Lua.tr(root.orig_general).charAt(index)
          font.pixelSize: 20
          color: "white"
          style: Text.Outline
        }
      }
    }
  }

  Flickable {
    id: skin
    height: contentHeight
    width: root.width - 90
    anchors.top: title.bottom
    anchors.topMargin: 20
    anchors.right: root.right
    contentWidth: skinRow.width
    contentHeight: skinRow.height + 25
    visible: !!(skinsRepeater.count > 0 && root.orig_general)
    clip: true

    Row {
      id: skinRow
      spacing: 6
      
      Repeater {
        id: skinsRepeater
        model: [root.orig_general].concat(root.skins ?? [])

        SkinItem {
          required property int index
          required property var modelData
          text: Lua.tr(modelData)
          source: {
            if (index === 0) {
              return SkinBank.getGeneralPicture(root.orig_general)
            } else {
              const skinData = Ltk.getSkinByName(root.orig_general, modelData)
              if (skinData) {
                return Ltk.getFullSkinPath(root.orig_general, modelData)
              }
              return SkinBank.getGeneralPicture("unknown")
            }
          }
          y: 25

          W.TapHandler {
            onTapped: {
              if (parent.index === 0) {
                root.selected_skin = "-";
              } else {
                root.selected_skin = parent.modelData;
              }
              
              for (let i = 0; i < skinsRepeater.count; i++) {
                if (i !== parent.index) {
                  skinsRepeater.itemAt(i).selected = false;
                }
              };
              parent.selected = true;
            }
          }
        }
      }
    }
  }

  Rectangle {
    id: deputyTitle
    anchors.left: root.left
    height: 170
    anchors.bottom: deputySkin.bottom
    anchors.bottomMargin: 17
    width: 80
    radius: 5
    color: '#79000000'
    visible: deputySkin.visible

    Column {
      anchors.centerIn: parent
      Repeater {
        model: Lua.tr(root.orig_deputy).length
        Text {
          required property int index
          text: Lua.tr(root.orig_deputy).charAt(index)
          font.pixelSize: 20
          color: "white"
          style: Text.Outline
        }
      }
    }
  }

  Flickable {
    id: deputySkin
    anchors.top: skin.visible ? skin.bottom : title.bottom
    width: root.width - 90
    anchors.right: root.right
    height: contentHeight
    contentWidth: deputySkinRow.width
    contentHeight: deputySkinRow.height + 25
    visible: !!(deputySkinsRepeater.count > 0 && root.orig_deputy)
    clip: true

    Row {
      id: deputySkinRow
      spacing: 6
      Repeater {
        id: deputySkinsRepeater
        model: [root.orig_deputy].concat(root.deputy_skins ?? [])

        SkinItem {
          required property int index
          required property var modelData
          text: Lua.tr(modelData)
          source: {
            if (index === 0) {
              return SkinBank.getGeneralPicture(root.orig_deputy)
            } else {
              const skinData = Ltk.getSkinByName(root.orig_deputy, modelData)
              if (skinData) {
                return Ltk.getFullSkinPath(root.orig_deputy, modelData)
              }
              return SkinBank.getGeneralPicture("unknown")
            }
          }
          y: 25

          W.TapHandler {
            onTapped: {
              if (parent.index === 0) {
                root.selected_deputy_skin = "-";
              } else {
                root.selected_deputy_skin = parent.modelData;
              }
              for (let i = 0; i < deputySkinsRepeater.count; i++) {
                if (i !== parent.index) {
                  deputySkinsRepeater.itemAt(i).selected = false;
                }
              };
              parent.selected = true;
            }
          }
        }
      }
    }
  }

  Row {
    spacing: 30
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    MetroButton {
      text: Lua.tr("OK")
      enabled: selected_skin || selected_deputy_skin
      onClicked: {
        Cpp.notifyServer("PushRequest", "changeskin," + selected_skin + "," + selected_deputy_skin)
        finish();
      }
    }

    MetroButton {
      text: Lua.tr("Cancel")
      onClicked: {
        finish();
      }
    }
  }

  
  
}
