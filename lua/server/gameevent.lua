-- SPDX-License-Identifier: GPL-3.0-or-later

---@class GameEvent: Object
---@field public id integer @ 事件的id，随着时间推移自动增加并分配给新事件
---@field public end_id integer @ 事件的对应结束id，如果整个事件中未插入事件，那么end_id就是自己的id
---@field public room Room @ room实例
---@field public event GameEvent @ 该事件对应的EventType，现已改为对应的class
---@field public data any @ 事件的附加数据，视类型而定
---@field public parent GameEvent @ 事件的父事件（栈中的上一层事件）
---@field public extra_clear fun(self:GameEvent)[] @ 事件结束时执行的自定义函数列表
---@field public extra_exit fun(self:GameEvent)[] @ 事件结束后执行的自定义函数
---@field public exec_ret boolean? @ exec函数的返回值，可能不存在
---@field public status string @ ready, running, exiting, dead
---@field public interrupted boolean @ 事件是否是因为被中断而结束的，可能是防止事件或者被杀
---@field public killed boolean @ 事件因为终止一切结算而被中断（所谓的“被杀”）
----@field public desc fun(self:GameEvent):LogMessage @ LogMessage形式的描述
----@field public getDesc fun(self:GameEvent):string @ 获得描述
local GameEvent = class("GameEvent")

---@type (fun(self: GameEvent): boolean?)[]
GameEvent.prepare_funcs = {}

---@type (fun(self: GameEvent): boolean?)[]
GameEvent.functions = {}

---@type (fun(self: GameEvent): boolean?)[]
GameEvent.cleaners = {}

---@type (fun(self: GameEvent): boolean?)[]
GameEvent.exit_funcs = {}

local dummyFunc = Util.DummyFunc

function GameEvent:initialize(event, ...)
  self.id = -1
  self.end_id = -1
  self.room = RoomInstance
  -- for compat
  self.event = event
  ---@diagnostic disable-next-line
  -- self.event = self.class
  self.data = { ... }
  if #self.data == 1 then self.data = self.data[1] end
  self.status = "ready"
  self.interrupted = false

  self.extra_clear = Util.DummyTable
  self.extra_exit = Util.DummyTable
end

---@generic T
---@param self T
---@return T
function GameEvent.create(self, ...)
  if self.class then error('cannot use "create()" by event instances') end
  return self:new(self, ...)
end

-- 获取最接近GameEvent的基类
---@return GameEvent
function GameEvent.getBaseClass(self, ...)
  if self.class then error('cannot use "getBaseClass()" by event instances') end
  if self.super == GameEvent or self == GameEvent then
    return self
  end
  return self.super:getBaseClass()
end

function GameEvent.static:subclassed(subclass)
  local mt = getmetatable(subclass)
  -- 适配老代码event == GameEvent.Turn之类的奇技淫巧，危险性待评估
  -- 这样若某个模式启用派生类修改逻辑，那么findParent之类的基于父类也能找
  mt.__eq = function(a, b)
    if not a.super or not b.super then return false end
    return rawequal(a, b) or a:isSubclassOf(b) or b:isSubclassOf(a)
  end
end

function GameEvent:__tostring()
  return string.format("<%s #%d>",
    type(self.event == "string") and self.event or self.class.name, self.id)
end

--- LogMessage形式的描述
---@return LogMessage
function GameEvent:desc()
  return { type = "#GameEvent" }-- .. (type(self.event == "string") and self.event or self.class.name)
end

---@param msg LogMessage
local function parseMsg(msg, nocolor, visible_data)
  local self = Fk:currentRoom()
  local data = msg
  local function getPlayerStr(pid, color)
    if nocolor then color = "white" end
    if not pid then
      return ""
    end
    local p = self:getPlayerById(pid)
    local str = '<font color="%s"><b>%s</b></font>'
    if p.general == "anjiang" and (p.deputyGeneral == "anjiang"
      or not p.deputyGeneral) then
      local ret = Fk:translate("seat#" .. p.seat)
      return string.format(str, color, ret)
    end

    local ret = p.general
    ret = Fk:translate(ret)
    if p.deputyGeneral and p.deputyGeneral ~= "" then
      ret = ret .. "/" .. Fk:translate(p.deputyGeneral)
    end
    for _, p2 in ipairs(Fk:currentRoom().players) do
      if p2 ~= p and p2.general == p.general and p2.deputyGeneral == p.deputyGeneral then
        ret = ret .. ("[%d]"):format(p.seat)
        break
      end
    end
    ret = string.format(str, color, ret)
    return ret
  end

  local from = getPlayerStr(data.from, "#0C8F0C")

  ---@type any
  local to = data.to or Util.DummyTable
  local to_str = {}
  for _, id in ipairs(to) do
    table.insert(to_str, getPlayerStr(id, "#CC3131"))
  end
  to = table.concat(to_str, ", ")

  ---@type any
  local card = data.card or Util.DummyTable
  local allUnknown = true
  local unknownCount = 0
  for _, id in ipairs(card) do
    local known = id ~= -1
    if visible_data then known = visible_data[tostring(id)] end
    if known then
      allUnknown = false
    else
      unknownCount = unknownCount + 1
    end
  end

  if allUnknown then
    card = ""
  else
    local card_str = {}
    for _, id in ipairs(card) do
      local known = id ~= -1
      if visible_data then known = visible_data[tostring(id)] end
      if known then
        table.insert(card_str, Fk:getCardById(id, true):toLogString())
      end
    end
    if unknownCount > 0 then
      local suffix = unknownCount > 1 and ("x" .. unknownCount) or ""
      table.insert(card_str, Fk:translate("unknown_card") .. suffix)
    end
    card = table.concat(card_str, ", ")
  end

  local function parseArg(arg)
    arg = arg or ""
    arg = Fk:translate(arg)
    arg = string.format('<font color="%s"><b>%s</b></font>', nocolor and "white" or "#0598BC", arg)
    return arg
  end

  local arg = parseArg(data.arg)
  local arg2 = parseArg(data.arg2)
  local arg3 = parseArg(data.arg3)

  local log = Fk:translate(data.type)
  log = string.gsub(log, "%%from", from)
  log = string.gsub(log, "%%to", to)
  log = string.gsub(log, "%%card", card)
  log = string.gsub(log, "%%arg2", arg2)
  log = string.gsub(log, "%%arg3", arg3)
  log = string.gsub(log, "%%arg", arg)
  return log
end
--- 获得Log描述
---@return string
function GameEvent:getDesc()
  return parseMsg(self:desc())
end

function GameEvent:prepare()
  return (GameEvent.prepare_funcs[self.event] or dummyFunc)(self)
end

function GameEvent:main()
  return (GameEvent.functions[self.event] or dummyFunc)(self)
end

function GameEvent:clear()
  return (GameEvent.cleaners[self.event] or dummyFunc)(self)
end

function GameEvent:exit()
  return (GameEvent.exit_funcs[self.event] or dummyFunc)(self)
end

function GameEvent:addCleaner(f)
  if self.extra_clear == Util.DummyTable then
    self.extra_clear= {}
  end
  table.insert(self.extra_clear, f)
end

function GameEvent:addExitFunc(f)
  if self.extra_exit== Util.DummyTable then
    self.extra_exit= {}
  end
  table.insert(self.extra_exit, f)
end

function GameEvent:prependExitFunc(f)
  if self.extra_exit== Util.DummyTable then
    self.extra_exit= {}
  end
  table.insert(self.extra_exit, 1, f)
end

-- 找第一个与当前事件有继承关系的特定事件
---@generic T: GameEvent
---@param eventType T @ 事件类型
---@param includeSelf boolean? @ 是否包括本事件
---@param depth? integer @ 搜索深度
---@return T?
function GameEvent:findParent(eventType, includeSelf, depth)
  if includeSelf and self.event == eventType then return self end
  if depth == 0 then return nil end
  local e = self.parent
  local l = 1
  while e do
    if e.event == eventType then return e end
    if depth and l >= depth then break end
    e = e.parent
    l = l + 1
  end
  return nil
end

-- 找n个id介于from和to之间的事件。
---@param events GameEvent[] @ 事件数组
---@param from integer @ 起始id
---@param to integer @ 终止id
---@param n integer @ 最多找多少个
---@param func fun(e: GameEvent): boolean? @ 过滤用的函数
---@return GameEvent[] @ 找到的符合条件的所有事件，最多n个但不保证有n个
local function bin_search(events, from, to, n, func)
  local left = 1
  local right = #events
  local mid
  local ret = {}

  if from < events[1].id then
    mid = 1
  elseif from > events[right].id then
    return ret
  else
    while true do
      if left > right then return ret end
      mid = (left + right) // 2
      local id = events[mid].id
      local id_left = mid == 1 and -math.huge or events[mid - 1].id

      if from < id then
        if from >= id_left then
          break
        end
        right = mid - 1
      else
        left = mid + 1
      end
    end
  end

  for i = mid, #events do
    local v = events[i]
    if v.id <= to and func(v) then
      table.insert(ret, v)
    end
    if #ret >= n then break end
  end

  return ret
end

-- 从某个区间中，找出类型符合且符合func函数检测的至多n个事件。
---@generic T: GameEvent
---@param eventType T @ 要查找的事件类型
---@param n integer @ 最多找多少个
---@param func fun(e: T): boolean? @ 过滤用的函数
---@param endEvent? GameEvent @ 区间终止点，默认为本事件结束
---@return T[] @ 找到的符合条件的所有事件，最多n个但不保证有n个
function GameEvent:searchEvents(eventType, n, func, endEvent)
  local logic = self.room.logic
  local events = logic.event_recorder[eventType] or Util.DummyTable
  local from = self.id
  local to = endEvent and endEvent.id or self.end_id
  if math.abs(to) == 1 then to = #logic.all_game_events end
  n = n or 1
  func = func or Util.TrueFunc

  local ret
  if #events < 6 then
    ret = {}
    for _, v in ipairs(events) do
      if v.id >= from and v.id <= to and func(v) then
        table.insert(ret, v)
      end
      if #ret >= n then break end
    end
  else
    ret = bin_search(events, from, to, n, func)
  end

  return ret
end

function GameEvent:exec()
  local room = self.room
  local logic = room.logic
  if self.status ~= "ready" then return true end

  self.parent = logic:getCurrentEvent()

  if self:prepare() then return true end

  logic:pushEvent(self)

  local co = coroutine.create(function() return self:main() end)
  self._co = co
  self.status = "running"

  coroutine.yield(self, "__newEvent")
  -- 事件的处理流程请看GameLogic:resumeEvent

  Pcall(self.exit, self)
  for _, f in ipairs(self.extra_exit) do
    if type(f) == "function" then
      Pcall(f, self)
    end
  end

  return self.interrupted, self.exec_ret
end

function GameEvent:shutdown()
  if self.status ~= "running" then return end
  -- yield to self and break
  coroutine.yield(self, "__breakEvent")
end

-- 应该也是两个通用event

---@class GameEvent.Game : GameEvent
local Game = GameEvent:subclass("GameEvent.Game")

function Game:__tostring()
  return string.format("<Game %s #%d>", Fk:currentRoom().settings.gameMode, self.id)
end

function Game:main()
  local room = self.room
  room.game_started = true
  room:doBroadcastNotify("StartGame", "")
  room.logic:run()
end

---@class GameEvent.ClearEvent : GameEvent
---@field data GameEvent
local ClearEvent = GameEvent:subclass("GameEvent.ClearEvent")
function ClearEvent:main()
  local event = self.data
  local logic = self.room.logic
  -- 不可中断
  Pcall(event.clear, event)
  for _, f in ipairs(event.extra_clear) do
    if type(f) == "function" then Pcall(f, event) end
  end

  -- cleaner顺利执行完了，出栈吧
  local end_id = logic.current_event_id + 1
  if event.id ~= end_id - 1 then
    logic.all_game_events[end_id] = event.event
    logic.current_event_id = end_id
    event.end_id = end_id
  else
    event.end_id = event.id
  end

  logic.game_event_stack:pop()
  logic.cleaner_stack:pop()
end

GameEvent.Game = Game
GameEvent.ClearEvent = ClearEvent

return GameEvent
