-- SPDX-License-Identifier: GPL-3.0-or-later

---@class GameEvent: Object
---@field public id integer @ 事件的id，随着时间推移自动增加并分配给新事件
---@field public end_id integer @ 事件的对应结束id，如果整个事件中未插入事件，那么end_id就是自己的id
---@field public room Room @ room实例
---@field public event integer @ 该事件对应的EventType
---@field public data any @ 事件的附加数据，视类型而定
---@field public parent GameEvent @ 事件的父事件（栈中的上一层事件）
---@field public prepare_func fun(self: GameEvent) @ 事件即将开始时执行的函数
---@field public main_func fun(self: GameEvent) @ 事件的主函数
---@field public clear_func fun(self: GameEvent) @ 事件结束时执行的函数
---@field public extra_clear_funcs fun(self:GameEvent)[] @ 事件结束时执行的自定义函数列表
---@field public exit_func fun(self: GameEvent) @ 事件结束后执行的函数
---@field public extra_exit_funcs fun(self:GameEvent)[] @ 事件结束后执行的自定义函数
---@field public exec_ret boolean? @ exec函数的返回值，可能不存在
---@field public status string @ ready, running, exiting, dead
---@field public interrupted boolean @ 事件是否是因为被中断而结束的，可能是防止事件或者被杀
---@field public killed boolean @ 事件因为终止一切结算而被中断（所谓的“被杀”）
local GameEvent = class("GameEvent")

---@type (fun(self: GameEvent): bool)[]
GameEvent.prepare_funcs = {}

---@type (fun(self: GameEvent): bool)[]
GameEvent.functions = {}

---@type (fun(self: GameEvent): bool)[]
GameEvent.cleaners = {}

---@type (fun(self: GameEvent): bool)[]
GameEvent.exit_funcs = {}

local function wrapCoFunc(f, ...)
  if not f then return nil end
  local args = {...}
  return function() return f(table.unpack(args)) end
end
local dummyFunc = Util.DummyFunc

function GameEvent:initialize(event, ...)
  self.id = -1
  self.end_id = -1
  self.room = RoomInstance
  self.event = event
  self.data = { ... }
  self.prepare_func = GameEvent.prepare_funcs[event] or dummyFunc
  self.main_func = wrapCoFunc(GameEvent.functions[event], self) or dummyFunc
  self.clear_func = GameEvent.cleaners[event] or dummyFunc
  self.extra_clear_funcs = Util.DummyTable
  self.exit_func = GameEvent.exit_funcs[event] or dummyFunc
  self.extra_exit_funcs = Util.DummyTable
  self.status = "ready"
  self.interrupted = false
end

-- 静态函数，实际定义在events/init.lua
function GameEvent:translate(id)
  error('static')
end

function GameEvent:__tostring()
  return string.format("<%s #%d>", GameEvent:translate(self.event), self.id)
end

function GameEvent:addCleaner(f)
  if self.extra_clear_funcs == Util.DummyTable then
    self.extra_clear_funcs = {}
  end
  table.insert(self.extra_clear_funcs, f)
end

function GameEvent:addExitFunc(f)
  if self.extra_exit_funcs == Util.DummyTable then
    self.extra_exit_funcs = {}
  end
  table.insert(self.extra_exit_funcs, f)
end

function GameEvent:prependExitFunc(f)
  if self.extra_exit_funcs == Util.DummyTable then
    self.extra_exit_funcs = {}
  end
  table.insert(self.extra_exit_funcs, 1, f)
end

-- 找第一个与当前事件有继承关系的特定事件
---@param eventType integer @ 事件类型
---@param includeSelf bool @ 是否包括本事件
---@param depth? integer @ 搜索深度
---@return GameEvent?
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
---@param eventType integer @ 要查找的事件类型
---@param n integer @ 最多找多少个
---@param func fun(e: GameEvent): boolean? @ 过滤用的函数
---@param endEvent? GameEvent @ 区间终止点，默认为本事件结束
---@return GameEvent[] @ 找到的符合条件的所有事件，最多n个但不保证有n个
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

  if self:prepare_func() then return true end

  logic:pushEvent(self)

  local co = coroutine.create(self.main_func)
  self._co = co
  self.status = "running"

  coroutine.yield(self, "__newEvent")

  Pcall(self.exit_func, self)
  for _, f in ipairs(self.extra_exit_funcs) do
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
