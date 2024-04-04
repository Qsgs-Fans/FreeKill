-- 在命令行中玩单机版FK吧！在游戏目录下 lua test/lua/play.lua
-- 只能在Linux或是Windows-MSYS2之类的环境运行
---@diagnostic disable: lowercase-global

package.path = package.path .. ";./test/lua/lib/?.lua"

lu = require('luaunit')
fk = require('fk')
fk.os = os
fk.io = io

local banner =
fk.CYAN .. [[    ______               __ __ _ ____]] .. fk.RST .. "\n" ..
fk.CYAN .. [[   / ____/_______  ___  / //_/(_) / /]] .. fk.RST .. "\n" ..
fk.CYAN .. [[  / /_  / ___/ _ \/ _ \/ ,<  / / / / ]] .. fk.RST .. "    命令行版本新月杀，仅供测试用\n" ..
fk.BLUE .. [[ / __/ / /  /  __/  __/ /| |/ / / /  ]] .. fk.RST .. "默认五人测试模式，请手动修改相关Lua文件\n" ..
fk.BLUE .. [[/_/   /_/   \___/\___/_/ |_/_/_/_/   ]] .. fk.RST .. "\n"
print(banner)

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

_TestGameLogic.setup()
_TestGameLogic.testTrigger()
_TestGameLogic.tearDown()
