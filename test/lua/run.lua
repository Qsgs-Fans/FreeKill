-- Run tests with `lua5.4 test/lua/run.lua`

---@diagnostic disable: lowercase-global

package.path = package.path .. ";./test/lua/lib/?.lua"

lu = require('luaunit')
local os = os
fk = require('fk')

dofile 'lua/freekill.lua'
dofile 'test/lua/pattern.lua'

os.exit( lu.LuaUnit.run() )
