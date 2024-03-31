-- Run tests with `lua5.4 test/lua/run.lua`
-- Can only run under Linux

---@diagnostic disable: lowercase-global

package.path = package.path .. ";./test/lua/lib/?.lua"
local os = os

lu = require('luaunit')
fk = require('fk')

-- load FreeKill core
dofile 'lua/freekill.lua'
fk.qlist = ipairs

-- load test cases
dofile 'test/lua/core/util.lua'
dofile 'test/lua/core/pattern.lua'
dofile 'test/lua/core/testmode.lua'

-- server tests
dofile 'lua/server/scheduler.lua'
Room = require 'server.room'
fk.Room = require 'test/lua/lib/room'
fk.ServerPlayer = require 'test/lua/lib/serverplayer'

dofile 'test/lua/server/scheduler.lua'
dofile 'test/lua/server/logic.lua'

os.exit( lu.LuaUnit.run() )
