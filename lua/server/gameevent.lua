-- SPDX-License-Identifier: GPL-3.0-or-later

---@class GameEvent: Object
---@field public room Room
---@field public event integer
---@field public data any
---@field public parent GameEvent
---@field public main_func fun(self: GameEvent)
---@field public clear_func fun(self: GameEvent)
---@field public extra_clear_funcs any[]
---@field public interrupted boolean
local GameEvent = class("GameEvent")

GameEvent.functions = {}
GameEvent.cleaners = {}
local function wrapCoFunc(f, ...)
  if not f then return nil end
  local args = {...}
  return function() return f(table.unpack(args)) end
end
local function dummyFunc() end

function GameEvent:initialize(event, ...)
  self.room = RoomInstance
  self.event = event
  self.data = { ... }
  self.main_func = wrapCoFunc(GameEvent.functions[event], self) or dummyFunc
  self.clear_func = GameEvent.cleaners[event] or dummyFunc
  self.extra_clear_funcs = {}
  self.interrupted = false
end

function GameEvent:__tostring()
  return GameEvent:translate(self.event)
end

function GameEvent:findParent(eventType)
  local e = self.parent
  repeat
    if e.event == eventType then return e end
    e = e.parent
  until not e
  return nil
end

function GameEvent:clear()
  local clear_co = coroutine.create(function()
    for _, f in ipairs(self.extra_clear_funcs) do
      if type(f) == "function" then f(self) end
    end
    self:clear_func()
  end)

  while true do
    local err, yield_result, extra_yield_result = coroutine.resume(clear_co)

    if err == false then
      -- handle error, then break
      if not string.find(yield_result, "__manuallyBreak") then
        fk.qCritical(yield_result)
        print(debug.traceback(co))
      end
      coroutine.close(clear_co)
      break
    end

    if yield_result == "__handleRequest" then
      -- yield to requestLoop
      coroutine.yield(yield_result, extra_yield_result)
    else
      coroutine.close(clear_co)
      break
    end
  end
end

local function breakEvent(self, extra_yield_result)
  local cancelEvent = GameEvent:new(GameEvent.BreakEvent, self)
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
  logic.game_event_stack:push(self)

  local co = coroutine.create(self.main_func)
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
        self:clear()
        logic.game_event_stack:pop(self)
        coroutine.close(co)

        -- then, call yield
        coroutine.yield(yield_result, extra_yield_result)
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

  logic.game_event_stack:pop(self)
  return ret, extra_ret
end

function GameEvent:shutdown()
  -- yield to self and break
  coroutine.yield(self, "__breakEvent")
end

return GameEvent
