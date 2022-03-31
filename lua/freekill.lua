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
Skill = require "core.skill"
Player = require "core.player"

-- load packages
dofile "lua/fk_ex.lua"
Fk = Engine:new()
