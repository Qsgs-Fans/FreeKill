-- SPDX-License-Identifier: GPL-3.0-or-later

-- 用于初始化FreeKill的最基本脚本
-- 向Lua虚拟机中加载库、游戏中的类，以及加载Mod等等。

-- 加载第三方库
package.path = "./?.lua;./?/init.lua;./lua/lib/?.lua;./lua/?.lua"

-- middleclass: 轻量级的面向对象库
class = require "middleclass"

-- json: 提供json处理支持，能解析JSON和生成JSON
-- 仍借助luajson处理简单类型。
local luajson = require "json"
json = {
  encode = function(val, t)
    if type(val) ~= "table" then return luajson.encode(val) end
    t = t or 1 -- Compact
    ---@diagnostic disable-next-line
    local doc = fk.QJsonDocument_fromVariant(val)
    local ret = doc:toJson(t)
    return ret
  end,
  decode = function(str)
    if str == "null" then return nil end
    local start = str:sub(1, 1)
    if start ~= "[" and start ~= "{" then
      return luajson.decode(str)
    end
    ---@diagnostic disable-next-line
    local doc = fk.QJsonDocument_fromJson(str)
    local ret = doc:toVariant()
    -- if ret == "" then ret = luajson.decode(str) end
    return ret
  end,
}

-- 初始化随机数种子
math.randomseed(os.time())

-- 加载实用类，让Lua编写起来更轻松。
local Utils = require "core.util"
-- TargetGroup, AimGroup, Util = table.unpack(Utils)
TargetGroup, AimGroup, Util = Utils[1], Utils[2], Utils[3]
dofile "lua/core/debug.lua"

-- 加载游戏核心类
Engine = require "core.engine"
Package = require "core.package"
General = require "core.general"
Card = require "core.card"
Exppattern = require "core.exppattern"
Skill = require "core.skill"
UsableSkill = require "core.skill_type.usable_skill"
StatusSkill = require "core.skill_type.status_skill"
Player = require "core.player"
GameMode = require "core.game_mode"
AbstractRoom = require "core.room.abstract_room"
RequestHandler = require "core.request_handler"
UI = require "ui-util"

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
local _os = {
  time = os.time,
  date = os.date,
  clock = os.clock,
  difftime = os.difftime,
  getms = os.getms,
}
os = _os
io = nil
package = nil
load = nil
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
