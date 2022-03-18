-- Fundemental script for FreeKill
-- Load mods, init the engine, etc.

package.path = package.path .. ";./lua/lib/?.lua"
                            .. ";./lua/core/?.lua"

-- load libraries
class = require "middleclass"
json = require "json"
Util = require "util"

DebugMode = true

function pt(t)
    for k, v in pairs(t) do
        print(k, v)
    end
end

-- load core classes
Sanguosha = require "engine"
General = require "general"
Card = require "card"
Skill = require "skill"

-- load packages
