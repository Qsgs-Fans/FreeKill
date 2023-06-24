// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: Backend.translate("BGM Volume")
    }
    Slider {
      from: 0
      to: 100
      value: config.bgmVolume
      onValueChanged: config.bgmVolume = value;
    }
  }

  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: Backend.translate("Effect Volume")
    }
    Slider {
      from: 0
      to: 100
      value: Backend.volume
      onValueChanged: Backend.volume = value;
    }
  }

  Switch {
    text: Backend.translate("Disable message audio")
    checked: config.disableMsgAudio
    onCheckedChanged: config.disableMsgAudio = checked;
  }

  Switch {
    text: Backend.translate("Hide unselectable cards")
    checked: config.hideUseless
    onCheckedChanged: {
      config.hideUseless = checked;
    }
  }

}
