local W = require "ui_emu.preferences"

local settings = {
  W.PreferenceGroup {
    title = "Properties",

    W.SpinRow {
      _settingsKey = "generalNum",
      title = "Select generals num",
      from = 3,
      to = 18,
    },

    W.SpinRow {
      _settingsKey = "generalTimeout",
      title = "Choose General timeout",
      from = 10,
      to = 60,
    },

    W.SpinRow {
      _settingsKey = "luckTime",
      title = "Luck Card Times",
      from = 0,
      to = 8,
    },
  },

  W.PreferenceGroup {
    title = "Game Rule",

    W.SwitchRow {
      _settingsKey = "enableFreeAssign",
      title = "Enable free assign",
    },

    W.SwitchRow {
      _settingsKey = "enableDeputy",
      title = "Enable deputy general",
    },
  },
}

Fk:addBoardGame {
  name = "lunarltk",
  room_klass = require "lunarltk.server.room",
  client_klass = require "lunarltk.client.client",
  engine = Fk,
  page = {
    uri = "Fk.Pages.LunarLTK",
    name = "Room",
  },
  ui_settings = settings,
}
