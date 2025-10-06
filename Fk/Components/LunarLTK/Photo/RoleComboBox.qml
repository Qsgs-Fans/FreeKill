// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Widgets as W

Image {
  property string value: "unknown"
  property var options: ["unknown", "loyalist", "rebel", "renegade"]

  id: root
  source: visible ? SkinBank.getRolePic(value) : ""
  visible: value != "hidden"
  width: 32
  height: 35

  Image {
    property string value: "unknown"

    id: assumptionBox
    source: SkinBank.getRolePic(value)
    visible: root.value == "unknown" && optionPopupBox.visible == false
    width: 32
    height: 35

    W.TapHandler {
      onTapped: optionPopupBox.visible = true;
    }
  }

  Column {
    id: optionPopupBox
    visible: false
    spacing: 2

    Repeater {
      model: options

      Image {
        source: SkinBank.getRolePic(modelData)
        width: 32
        height: 35

        W.TapHandler {
          onTapped: {
            optionPopupBox.visible = false;
            assumptionBox.value = modelData;
          }
        }
      }
    }
  }
}
