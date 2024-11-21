-- Run tests with `cmake TestLuaCore && ctest`

---@diagnostic disable: lowercase-global

__package.path = __package.path .. ";./test/lua/lib/?.lua"

fk.os = __os
fk.io = __io
lu = require('luaunit')

-- load FreeKill core
dofile 'lua/client/i18n/init.lua'

-- load test cases
dofile 'test/lua/core/util.lua'
dofile 'test/lua/core/pattern.lua'
dofile 'test/lua/core/testmode.lua'

fk.os.exit( lu.LuaUnit.run() )
