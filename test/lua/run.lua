-- Run tests with `lua5.4 test/lua/run.lua`
-- Can only run under Linux

---@diagnostic disable: lowercase-global

package.path = package.path .. ";./test/lua/lib/?.lua"

lu = require('luaunit')
fk = require('fk')
function fk.GetDisabledPacks()
  local pkgs = fk.QmlBackend_ls("packages")
  table.removeOne(pkgs, "test")
  return json.encode(pkgs)
end
fk.os = os
fk.io = io

-- load FreeKill core
dofile 'lua/freekill.lua'
fk.qlist = ipairs
dofile 'lua/client/i18n/init.lua'

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

fk.os.exit( lu.LuaUnit.run() )
