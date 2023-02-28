---@class GameEvent: Object
---@field room Room
---@field event integer
---@field data any
local GameEvent = class("GameEvent")

GameEvent.functions = {}
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
  local func_tab = GameEvent.functions[event] or {}
  self.main_func = wrapCoFunc(func_tab[1], self) or dummyFunc
  self.clear_func = wrapCoFunc(func_tab[2], self) or dummyFunc
end

function GameEvent:exec()
  local room = self.room
  local logic = room.logic
  local ret = false -- false or nil means this event is running normally
  local extra_ret
  logic.game_event_stack:push(self)
  
  local co = coroutine.create(self.main_func)
  while true do
    local err, yield_result, extra_yield_result = coroutine.resume(co)

    if err == false then
      -- handle error, then break
      if yield_result ~= "__manuallyBreak" then
        fk.qCritical(yield_result)
        print(debug.traceback(co))
      end
      self.clear_func()
      ret = true
      break
    end

    if yield_result == "__handleRequest" then
      -- yield to requestLoop
      coroutine.yield(yield_result, extra_yield_result)

    elseif type(yield_result) == "table" and yield_result.class
      and yield_result:isInstanceOf(GameEvent) then
      -- yield to corresponding GameEvent, first pop self from stack
      self.clear_func()
      logic.game_event_stack:pop(self)

      -- then, call yield
      coroutine.yield(yield_result)

    elseif yield_result == "__breakEvent" then
      -- try to break this event
      local cancelEvent = GameEvent:new(GameEvent.BreakEvent, self)
      local notcanceled = cancelEvent:exec()
      if not notcanceled then
        self.clear_func()
        ret = true
        extra_ret = extra_yield_result
        break
      end

    else
      -- normally exit, simply break the loop
      extra_ret = yield_result
      break
    end
  end

  logic.game_event_stack:pop(self)
  return ret, extra_ret
end

return GameEvent
