// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Fk.Widgets as W

W.PreferencePage {
  groupWidth: width * 0.8

  W.PreferenceGroup {

  W.SwitchRow {
    title: luatr("Hide unselectable cards")
    subTitle: luatr("help: Hide unselectable cards")
    checked: config.hideUseless
    onCheckedChanged: config.hideUseless = checked;
  }

  W.SwitchRow {
    title: luatr("Rotate table card")
    subTitle: luatr("help: Rotate table card")
    checked: config.rotateTableCard
    onCheckedChanged: config.rotateTableCard = checked;
  }

  W.SwitchRow {
    title: luatr("Auto select the only target")
    subTitle: luatr("help: Auto select the only target")
    checked: config.autoTarget
    onCheckedChanged: config.autoTarget = checked;
  }

  W.SwitchRow {
    title: luatr("Double click to use card or skill")
    subTitle: luatr("help: Double click to use card or skill")
    checked: config.doubleClickUse
    onCheckedChanged: config.doubleClickUse = checked;
  }

  W.SwitchRow {
    title: luatr("Do not use nullification to own one-target trick")
    subTitle: luatr("help: Do not use nullification to own one-target trick")
    checked: config.noSelfNullification
    onCheckedChanged: config.noSelfNullification = checked;
  }

  }

}
