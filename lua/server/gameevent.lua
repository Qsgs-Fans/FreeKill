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
---@field public interrupted boolean @ 事件是否是因为被中断而结束的，可能是防止事件或者被杀
---@field public killed boolean @ 事件因为终止一切结算而被中断（所谓的“被杀”）
---@field public revived boolean @ 事件被killed，但因为在cleaner中发生而被复活
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

function GameEvent:findParent(eventType, includeSelf)
  if includeSelf and self.event == eventType then return self end
  local e = self.parent
  repeat
    if e.event == eventType then return e end
    e = e.parent
  until not e
  return nil
end

-- 找n个id介于from和to之间的事件。
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
---@param func fun(e: GameEvent): boolean @ 过滤用的函数
---@param endEvent GameEvent|nil @ 区间终止点，默认为本事件结束
---@return GameEvent[] @ 找到的符合条件的所有事件，最多n个但不保证有n个
function GameEvent:searchEvents(eventType, n, func, endEvent)
  local logic = self.room.logic
  local events = logic.event_recorder[eventType] or Util.DummyTable
  local from = self.id
  local to = endEvent and endEvent.id or self.end_id
  if to == -1 then to = #logic.all_game_events end
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

function GameEvent:clear()
  local clear_co = coroutine.create(function()
    self:clear_func()
    for _, f in ipairs(self.extra_clear_funcs) do
      if type(f) == "function" then f(self) end
    end
  end)

  local zhuran_jmp, zhuran_msg -- SB老朱然

  while true do
    local err, yield_result, extra_yield_result = coroutine.resume(clear_co)

    if err == false then
      -- handle error, then break
      if not string.find(yield_result, "__manuallyBreak") then
        fk.qCritical(yield_result)
        print(debug.traceback(clear_co))
      end
      coroutine.close(clear_co)
      break
    end

    if yield_result == "__handleRequest" then
      -- yield to requestLoop
      coroutine.yield(yield_result, extra_yield_result)

    elseif type(yield_result) == "table" and yield_result.class
      and yield_result:isInstanceOf(GameEvent) and self ~= yield_result then

      -- 不是，谁TM还在cleaner里面玩老朱然啊
      -- 总之，cleaner不能断
      -- 倒是没必要手动resume，新一轮while true会自动resume，只要把返回值
      -- 传回去就行

      -- 一般来说都是由cleaner中的trigger引起
      -- 以胆守合击为例就是trigger -> SkillEffect事件 -> UseCard事件 -> 胆守
      -- 此时胆守的话最后从SkillEffect事件的exec内部yield出来
      -- 当前协程就应该正在执行room:useSkill函数，resume会去只会让那个函数返回

      if zhuran_jmp == nil or zhuran_jmp.id > yield_result.id then
        zhuran_jmp = yield_result
        zhuran_msg = extra_yield_result
      end

      -- 自己本来应该被杀的但是因为自己正在执行self:clear()而逃过一劫啊
      -- 还是得标记一下被杀才行，顺便因为实际上没死所以标记被复活
      self.killed = true
      self.revived = true
      -- 什么都不做，等下轮while自己resume
    else
      coroutine.close(clear_co)
      break
    end
  end

  -- cleaner顺利执行完了，出栈吧
  local logic = RoomInstance.logic
  local end_id = logic.current_event_id + 1
  if self.id ~= end_id - 1 then
    logic.all_game_events[end_id] = self.event
    logic.current_event_id = end_id
    self.end_id = end_id
  else
    self.end_id = self.id
  end

  logic.game_event_stack:pop()

  -- 好了确保cleaner走完了，此时中断就会进入下层事件的正常中断处理
  if zhuran_jmp then
    coroutine.close(self._co)
    coroutine.yield(zhuran_jmp, zhuran_msg)

    -- 此时仍可能出现在插结在其他事件的clear函数中
    -- 但就算被交付回去了，也能安然返回而不是继续while
    -- 但愿如此吧
  end

  -- 保险而已，其实如果被杀的话应该已经在前面的yield终止了
  -- 但担心cleaner嵌套（三国杀是这样的）还是补一刀
  if self.killed then return end

  -- 恭喜没被杀掉，我们来执行一些事件结束之后的结算吧
  Pcall(self.exit_func, self)
  for _, f in ipairs(self.extra_exit_funcs) do
    if type(f) == "function" then
      Pcall(f, self)
    end
  end
end

local function breakEvent(self, extra_yield_result)
  local cancelEvent = GameEvent:new(GameEvent.BreakEvent, self)
  cancelEvent.toId = self.id
  local notcanceled = cancelEvent:exec()
  local ret, extra_ret = false, nil
  if not notcanceled then
    self.interrupted = true
    self:clear()
    ret = true
    extra_ret = extra_yield_result
  end
  return ret, extra_ret
end

function GameEvent:exec()
  local room = self.room
  local logic = room.logic
  local ret = false -- false or nil means this event is running normally
  local extra_ret
  self.parent = logic:getCurrentEvent()

  if self:prepare_func() then return true end

  logic.game_event_stack:push(self)

  logic.current_event_id = logic.current_event_id + 1
  self.id = logic.current_event_id
  logic.all_game_events[self.id] = self
  logic.event_recorder[self.event] = logic.event_recorder[self.event] or {}
  table.insert(logic.event_recorder[self.event], self)

  local co = coroutine.create(self.main_func)
  self._co = co
  while true do
    local err, yield_result, extra_yield_result = coroutine.resume(co)

    if err == false then
      -- handle error, then break
      if not string.find(yield_result, "__manuallyBreak") then
        fk.qCritical(yield_result)
        print(debug.traceback(co))
      end
      self.interrupted = true
      self:clear()
      ret = true
      coroutine.close(co)
      break
    end

    if yield_result == "__handleRequest" then
      -- yield to requestLoop
      coroutine.yield(yield_result, extra_yield_result)

    elseif type(yield_result) == "table" and yield_result.class
      and yield_result:isInstanceOf(GameEvent) then

      if self ~= yield_result then
        -- yield to corresponding GameEvent, first pop self from stack
        self.interrupted = true
        self.killed = true  -- 老朱然！你不得好死
        self:clear()
        -- logic.game_event_stack:pop(self)
        coroutine.close(co)

        -- then, call yield
        coroutine.yield(yield_result, extra_yield_result)

        -- 如果是在cleaner/exit里面发生此类中断的话是会被cleaner原地返回的
        -- 此时正常执行程序流就变成继续while循环了，这是不行的
        break
      elseif extra_yield_result == "__breakEvent" then
        if breakEvent(self) then
          coroutine.close(co)
          break
        end
      end

    elseif yield_result == "__breakEvent" then
      -- try to break this event
      if breakEvent(self) then
        coroutine.close(co)
        break
      end

    else
      -- normally exit, simply break the loop
      self:clear()
      extra_ret = yield_result
      coroutine.close(co)
      break
    end
  end

  return ret, extra_ret
end

function GameEvent:shutdown()
  -- yield to self and break
  coroutine.yield(self, "__breakEvent")
end

return GameEvent
