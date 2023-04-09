-- SPDX-License-Identifier: GPL-3.0-or-later

-- Fundemental script for FreeKill
-- Load mods, init the engine, etc.

package.path = package.path .. ";./lua/lib/?.lua"
                            .. ";./lua/?.lua"

-- load libraries

class = require "middleclass"
json = require "json"

local GroupUtils = require "core.util"
TargetGroup, AimGroup = table.unpack(GroupUtils)
dofile "lua/core/debug.lua"

math.randomseed(os.time())

-- load core classes
Engine = require "core.engine"
Package = require "core.package"
General = require "core.general"
Card = require "core.card"
Exppattern = require "core.exppattern"
Skill = require "core.skill"
UsableSkill = require "core.skill_type.usable_skill"
StatusSkill = require "core.skill_type.status_skill"
Player = require "core.player"
GameMode = require "core.game_mode"
UI = require "ui-util"

-- load config
local function loadConf()
  local cfg = io.open("freekill.client.config.json")
  local ret
  if cfg == nil then
    ret = {
      language = "zh_CN",
    }
  else
    ret = json.decode(cfg:read("a"))
    cfg:close()
  end
  return ret
end
Config = loadConf()

-- disable dangerous functions
local _os = {
  time = os.time,
  date = os.date,
  clock = os.clock,
  difftime = os.difftime,
  getms = os.getms,
}
os = _os
io = nil
package = nil
load = nil
loadfile = nil

-- load packages
dofile "lua/fk_ex.lua"
Fk = Engine:new()
