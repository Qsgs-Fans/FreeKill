-- Run tests with `cmake TestLuaCore && ctest`

---@diagnostic disable: lowercase-global
---@diagnostic disable: undefined-global

__package.path = __package.path .. ";./test/lua/lib/?.lua"

fk.os = __os
fk.io = __io
lu = require('luaunit')

-- load FreeKill core
dofile 'lua/client/i18n/init.lua'

-- 加载测试用例
-- 测试框架是LuaUnit 文档参见 https://luaunit.readthedocs.io/en/luaunit_v3_2_1/
dofile 'test/lua/core/init.lua'
