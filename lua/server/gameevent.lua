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

return GameEvent
