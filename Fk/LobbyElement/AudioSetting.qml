// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Fk.Widgets as W

W.PreferencePage {
  groupWidth: width * 0.8

  W.PreferenceGroup {

  W.SliderRow {
    title: luatr("BGM Volume")
    from: 0
    to: 100
    value: config.bgmVolume
    onValueChanged: config.bgmVolume = value;
  }

  W.SliderRow {
    title: luatr("Effect Volume")
    from: 0
    to: 100
    value: Backend.volume
    onValueChanged: Backend.volume = value;
  }

  W.SwitchRow {
    title: luatr("Disable message audio")
    subTitle: luatr("help: Disable message audio")
    checked: config.disableMsgAudio
    onCheckedChanged: config.disableMsgAudio = checked;
  }

  W.SwitchRow {
    title: luatr("Disable game over audio")
    subTitle: luatr("help: Disable game over audio")
    checked: config.disableGameOverAudio
    onCheckedChanged: config.disableGameOverAudio = checked;
  }

  W.SwitchRow {
    title: luatr("Hide observer chatter")
    subTitle: luatr("help: Hide observer chatter")
    checked: config.hideObserverChatter
    onCheckedChanged: config.hideObserverChatter = checked;
  }

  W.SwitchRow {
    title: luatr("Hide presents")
    subTitle: luatr("help: Hide presents")
    checked: config.hidePresents
    onCheckedChanged: config.hidePresents = checked;
  }

  }

}
