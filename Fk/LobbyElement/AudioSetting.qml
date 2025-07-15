// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
  RowLayout {
    anchors.rightMargin: 8
    spacing: 16
    Text {
      text: luatr("BGM Volume")
    }
    Slider {
      Layout.rightMargin: 16
      Layout.fillWidth: true
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
      text: luatr("Effect Volume")
    }
    Slider {
      Layout.rightMargin: 16
      Layout.fillWidth: true
      from: 0
      to: 100
      value: Backend.volume
      onValueChanged: Backend.volume = value;
    }
  }

  Grid {
    columns: 2

  Switch {
    text: luatr("Disable message audio")
    checked: config.disableMsgAudio
    onCheckedChanged: config.disableMsgAudio = checked;
  }

  Switch {
    text: luatr("Disable game over audio")
    checked: config.disableGameOverAudio
    onCheckedChanged: config.disableGameOverAudio = checked;
  }

  Switch {
    text: luatr("Hide unselectable cards")
    checked: config.hideUseless
    onCheckedChanged: {
      config.hideUseless = checked;
    }
  }

  Switch {
    text: luatr("Hide observer chatter")
    checked: config.hideObserverChatter
    onCheckedChanged: {
      config.hideObserverChatter = checked;
    }
  }

  Switch {
    text: luatr("Rotate table card")
    checked: config.rotateTableCard
    onCheckedChanged: {
      config.rotateTableCard = checked;
    }
  }

  Switch {
    text: luatr("Hide presents")
    checked: config.hidePresents
    onCheckedChanged: {
      config.hidePresents = checked;
    }
  }

  Switch {
    text: luatr("Auto select the only target")
    checked: config.autoTarget
    onCheckedChanged: {
      config.autoTarget = checked;
    }
  }

  Switch {
    text: luatr("Double click to use card or skill")
    checked: config.doubleClickUse
    onCheckedChanged: {
      config.doubleClickUse = checked;
    }
  }

  Switch {
    text: luatr("Do not use nullification to own one-target trick")
    checked: config.noSelfNullification
    onCheckedChanged: {
      config.noSelfNullification = checked;
    }
  }

  }
}
