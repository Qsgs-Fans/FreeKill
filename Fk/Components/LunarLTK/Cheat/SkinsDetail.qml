// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import Fk.Components.LunarLTK
import Fk.Widgets as W
import Fk.Components.Common
import Qt5Compat.GraphicalEffects

Item {
  id: root
  property var extra_data: ({})
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
        model: Lua.tr(extra_data.orig_general).length
        Text {
          text: Lua.tr(extra_data.orig_general).charAt(index)
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
    visible: !!(skinsRepeater.count > 0 && extra_data.orig_general)
    clip: true

    Row {
      id: skinRow
      spacing: 6
      
      Repeater {
        id: skinsRepeater
        model: [extra_data.orig_general].concat(extra_data.skins ?? [])

        SkinItem {
          source: {
            if (index === 0) {
              return SkinBank.getGeneralPicture(extra_data.orig_general)
            } else {
              return Cpp.path + "/" + modelData
            }
          }
          y: 25

          W.TapHandler {
            onTapped: {
              if (index === 0) {
                root.selected_skin = "-";
              } else {
                root.selected_skin = source;
              }
              
              for (let i = 0; i < skinsRepeater.count; i++) {
                if (i !== index) {
                  skinsRepeater.itemAt(i).selected = false;
                }
              };
              selected = true;
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
        model: Lua.tr(extra_data.orig_deputy).length
        Text {
          text: Lua.tr(extra_data.orig_deputy).charAt(index)
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
    visible: !!(deputySkinsRepeater.count > 0 && extra_data.orig_deputy)
    clip: true

    Row {
      id: deputySkinRow
      spacing: 6
      Repeater {
        id: deputySkinsRepeater
        model: [extra_data.orig_deputy].concat(extra_data.deputy_skins ?? [])

        SkinItem {
          source: {
            if (index === 0) {
              return SkinBank.getGeneralPicture(extra_data.orig_deputy)
            } else {
              return Cpp.path + "/" + modelData
            }
          }
          y: 25

          W.TapHandler {
            onTapped: {
              if (index === 0) {
                root.selected_deputy_skin = "-";
              } else {
                root.selected_deputy_skin = source;
              }
              for (let i = 0; i < deputySkinsRepeater.count; i++) {
                if (i !== index) {
                  deputySkinsRepeater.itemAt(i).selected = false;
                }
              };
              selected = true;
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
        roomScene.closeCheat()
      }
    }

    MetroButton {
      text: Lua.tr("Cancel")
      onClicked: {
        roomScene.closeCheat()
      }
    }
  }

  
  
}
