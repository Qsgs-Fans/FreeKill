// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import Fk.Widgets as W

W.PreferencePage {
  groupWidth: width * 0.8

  W.PreferenceGroup {

    W.SwitchRow {
      title: Lua.tr("Hide unselectable cards")
      subTitle: Lua.tr("help: Hide unselectable cards")
      checked: Config.hideUseless
      onCheckedChanged: Config.hideUseless = checked;
    }

    W.SwitchRow {
      title: Lua.tr("Rotate table card")
      subTitle: Lua.tr("help: Rotate table card")
      checked: Config.rotateTableCard
      onCheckedChanged: Config.rotateTableCard = checked;
    }

  }

  W.PreferenceGroup {
    W.SwitchRow {
      title: Lua.tr("Auto select the only target")
      subTitle: Lua.tr("help: Auto select the only target")
      checked: Config.autoTarget
      onCheckedChanged: Config.autoTarget = checked;
    }

    /*
     W.SwitchRow {
       title: Lua.tr("Double click to use card or skill")
       subTitle: Lua.tr("help: Double click to use card or skill")
       checked: Config.doubleClickUse
       onCheckedChanged: Config.doubleClickUse = checked;
     }
     */

    W.SwitchRow {
      title: Lua.tr("Do not use nullification to own one-target trick")
      subTitle: Lua.tr("help: Do not use nullification to own one-target trick")
      checked: Config.noSelfNullification
      onCheckedChanged: Config.noSelfNullification = checked;
    }

    W.SwitchRow {
      title: Lua.tr("Enable Super Drag")
      subTitle: Lua.tr("help: Enable Super Drag")
      checked: Config.enableSuperDrag
      onCheckedChanged: Config.enableSuperDrag = checked;
    }
  }

}
