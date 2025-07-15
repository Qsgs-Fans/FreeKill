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

  Image {
    property string value: "unknown"

    id: assumptionBox
    source: SkinBank.ROLE_DIR + value
    visible: root.value == "unknown" && optionPopupBox.visible == false

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
        source: SkinBank.ROLE_DIR + modelData

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
