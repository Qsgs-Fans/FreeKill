// SPDX-License-Identifier: GPL-3.0-or-later

// 武将界面皮肤一览
import QtQuick
import QtQuick.Layouts

import Fk
import LunarLtk

Flickable {
  id: root
  property string general: ""
  clip: true
  contentHeight: skinFlow.implicitHeight + skinFlow.y

  Flow {
    id: skinFlow
    width: parent.width
    y: 20
    spacing: 5

    Repeater {
      id: skinRepeater
      model: Ltk.getSkinNamesByGeneral(root.general)
      delegate: SkinItem {
        required property string modelData
        required property string index
        general: root.general
        skinName: modelData
        text: Lua.tr(modelData)

        onClicked: {
          if (selected) {
            Config.enabledSkins[root.general] = modelData
            for (let i = 0; i < skinRepeater.model.length; i++) {
              let item = skinRepeater.itemAt(i);
              if (item.index !== index) {
                item.selected = false;
              }
            }
          } else delete Config.enabledSkins[root.general];
        }

        Component.onCompleted: {
          if (Config.enabledSkins[root.general] === modelData) {
            selected = true
          }
        }
      }
    }
  }
}