-- SPDX-License-Identifier: GPL-3.0-or-later

-- 用于初始化FreeKill的最基本脚本
-- 向Lua虚拟机中加载库、游戏中的类，以及加载Mod等等。

-- 加载第三方库
package.path = "./?.lua;./?/init.lua;./lua/lib/?.lua;./lua/?.lua;./lua/?/init.lua"

-- middleclass: 轻量级的面向对象库
class = require "middleclass"

-- 老json只能待命了
json = require "json"

-- 调用此函数可创建单独的随机数发生器 行为与math.random一致，但保存单独的状态。
fk.rand = require "xoshiro256starstar"

cbor = require "server.rpc.cbor"

-- 初始化随机数种子
math.randomseed(os.time())

-- 加载实用类，让Lua编写起来更轻松。
Util = require "core.util"
dofile "lua/core/debug.lua"

-- 加载游戏核心类
Engine = require "ltk.core.engine"
Package = require "ltk.core.package"
General = require "ltk.core.general"
CardSkeleton = require "ltk.core.card_skeleton"
Card = require "ltk.core.card"
Exppattern = require "ltk.core.exppattern"
SkillSkeleton = require "ltk.core.skill_skeleton"
Skill = require "ltk.core.skill"
UsableSkill = require "ltk.core.skill_type.usable_skill"
StatusSkill = require "ltk.core.skill_type.status_skill"
Player = require "ltk.core.player"
GameMode = require "core.game_mode"
RequestHandler = require "core.request_handler"
AbstractRoom = require "ltk.core.room.abstract_room"
UI = require "ui-util"
GameEvent = require "server.gameevent"

-- 读取配置文件。
-- 因为io马上就要被禁用了，所以赶紧先在这里读取配置文件。
local function loadConf()
  local new_core = FileIO.pwd():endsWith("packages/freekill-core")

  local cfg = io.open((new_core and "../../" or "") .. "freekill.client.config.json")
  local ret
  if cfg == nil then
    ret = {
      language = "zh_CN",
    }
  else
    ret = json.decode(cfg:read("a"))
    cfg:close()
  end
  return ret
end
Config = loadConf()

-- 禁用各种危险的函数，尽可能让Lua执行安全的代码。
os = {
  time = os.time,
  date = os.date,
  clock = os.clock,
  difftime = os.difftime,
  getms = os.getms,
}
local _open = io.open
io = {
  open = function(f, mode)
    local errmsg = "Refusing open file that not in game directory"
    assert(not f:startsWith("/"), errmsg)
    assert(not f:startsWith(".."), errmsg)
    assert(not f:find(":"), errmsg)
    if mode and mode ~= "r" and mode ~= "rb" then
      error("Cannot open a file with read-only mode")
    end
    return _open(f, mode)
  end,
}
package = nil
-- load = nil
loadfile = nil
local _dofile = dofile
dofile = function(f)
  local errmsg = "Refusing dofile that not in game directory"
  assert(not f:startsWith("/"), errmsg)
  assert(not f:startsWith(".."), errmsg)
  assert(not f:find(":"), errmsg)
  return _dofile(f)
end

-- 初始化Engine类并置于Fk全局变量中，这里会加载拓展包
dofile "lua/fk_ex.lua"

Fk = Engine:new()
dofile "ltk/init.lua"

-- C++注入的快速启动配置（仅单机模式存在）
if __quickStartConfig then
  Fk.quickStartConfig = json.decode(__quickStartConfig)
  __quickStartConfig = nil
end
Fk:loadPackages()

local boardgameCount = 0
for _, game in pairs(Fk.boardgames) do
  local engine = game.engine
  engine:postLoad()
  boardgameCount = boardgameCount + 1
end
fk.qInfo(string.format("[Core] Loaded %d boardgame(s).", boardgameCount))

local gamemodeCount = 0
for _ in pairs(Fk.game_modes) do
  gamemodeCount = gamemodeCount + 1
end
fk.qInfo(string.format("[Core] Loaded %d game mode(s).", gamemodeCount))
