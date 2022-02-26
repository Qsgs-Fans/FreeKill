-- Fundemental script for FreeKill
-- Load mods, init the engine, etc.

package.path = package.path .. ';./lua/lib/?.lua'

-- load libraries
class = require 'middleclass'
json = require 'json'

function pt(t)
    for k, v in pairs(t) do
        print(k, v)
    end
end

-- load core classes
