// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import Fk.Widgets as W

W.PreferencePage {
  groupWidth: width * 0.8

  W.PreferenceGroup {

  W.SliderRow {
    title: Lua.tr("BGM Volume")
    from: 0
    to: 100
    value: Config.bgmVolume
    onValueChanged: Config.bgmVolume = value;
  }

  W.SliderRow {
    title: Lua.tr("Effect Volume")
    from: 0
    to: 100
    value: Backend.volume
    onValueChanged: Backend.volume = value;
  }

  W.SwitchRow {
    title: Lua.tr("Disable message audio")
    subTitle: Lua.tr("help: Disable message audio")
    checked: Config.disableMsgAudio
    onCheckedChanged: Config.disableMsgAudio = checked;
  }

  W.SwitchRow {
    title: Lua.tr("Disable game over audio")
    subTitle: Lua.tr("help: Disable game over audio")
    checked: Config.disableGameOverAudio
    onCheckedChanged: Config.disableGameOverAudio = checked;
  }

  W.SwitchRow {
    title: Lua.tr("Hide observer chatter")
    subTitle: Lua.tr("help: Hide observer chatter")
    checked: Config.hideObserverChatter
    onCheckedChanged: Config.hideObserverChatter = checked;
  }

  W.SwitchRow {
    title: Lua.tr("Hide presents")
    subTitle: Lua.tr("help: Hide presents")
    checked: Config.hidePresents
    onCheckedChanged: Config.hidePresents = checked;
  }

  }

}
