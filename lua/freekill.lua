-- Fundemental script for FreeKill
-- Load mods, init the engine, etc.

package.path = package.path .. ";./lua/lib/?.lua"
                            .. ";./lua/?.lua"

-- load libraries

class = require "middleclass"
json = require "json"

dofile "lua/lib/sha256.lua"
dofile "lua/core/util.lua"

math.randomseed(os.time())

DebugMode = true

function pt(t)
    for k, v in pairs(t) do
        print(k, v)
    end
end

-- load core classes
Engine = require "core.engine"
Package = require "core.package"
General = require "core.general"
Card = require "core.card"
SkillCard = require "core.card_type.skill"
BasicCard = require "core.card_type.basic"
TrickCard = require "core.card_type.trick"
EquipCard = require "core.card_type.equip"
Skill = require "core.skill"
Player = require "core.player"

-- load packages
Fk = Engine:new()
