---@class Base.GameLogic : Object
---@field public room Room
---@field public skill_table table<(TriggerEvent|integer|string), TriggerSkill[]>
---@field public skill_priority_table table<(TriggerEvent|integer|string), number[]>
---@field public skills string[]
---@field public game_event_stack Stack
---@field public cleaner_stack Stack
---@field public all_game_events GameEvent[]
---@field public event_recorder table<GameEvent, GameEvent>
---@field public current_event_id integer
---@field public current_trigger_event_id integer
local GameLogic = class("Base.GameLogic")

function GameLogic:initialize(room)
  self.room = room

  self.skills = {}
  self.skill_table = {}
  self.skill_priority_table = {}

  self.game_event_stack = Stack:new()
  self.cleaner_stack = Stack:new()
  self.all_game_events = {}
  self.event_recorder = setmetatable({}, {
    -- 对派生事件而言 共用一个键 键取决于最接近GameEvent类的基类
    __newindex = function(t, k, v)
      if type(k) == "table" and k:isSubclassOf(GameEvent) then
        k = k:getBaseClass()
      end
      rawset(t, k, v)
    end,
    __index = function(t, k)
      if type(k) == "table" and k:isSubclassOf(GameEvent) then
        k = k:getBaseClass()
      end
      return rawget(t, k)
    end,
  })
  self.current_event_id = 0
  self.specific_events_id = {
    [GameEvent.Damage] = 1,
  }
  self.current_trigger_event_id = 0
end

-- 待子类重写
function GameLogic:run()
  print "Hello, world."
end

--- 安排座位。若有主公则作为1号位
function GameLogic:adjustSeats()
  local player_circle = {}
  local players = self.room.players
  local p = 1

  for i = 1, #players do
    if players[i].role == "lord" then
      p = i
      break
    end
  end
  for j = p, #players do
    table.insert(player_circle, players[j])
  end
  for j = 1, p - 1 do
    table.insert(player_circle, players[j])
  end

  self.room:arrangeSeats(player_circle)
end

--- 将一个触发技和它的关联触发技添加到房间（触发技必须添加到房间才能正常触发）
---@param skill TriggerSkill --|LegacyTriggerSkill
function GameLogic:addTriggerSkill(skill)
  if not skill then return end
  -- if skill:isInstanceOf(LegacyTriggerSkill) then
  --   ---@cast skill LegacyTriggerSkill
  --   self:addLegacyTriggerSkill(skill)
  --   return
  -- end

  ---@cast skill TriggerSkill
  if table.contains(self.skills, skill.name) then return end
  table.insert(self.skills, skill.name)
  local event = skill.event
  if self.skill_table[event] == nil then self.skill_table[event] = {} end
  table.insert(self.skill_table[event], skill)

  if self.skill_priority_table[event] == nil then
    self.skill_priority_table[event] = {}
  end

  local priority_tab = self.skill_priority_table[event]
  local prio = skill.priority
  if not table.contains(priority_tab, prio) then
    for i, v in ipairs(priority_tab) do
      if v < prio then
        table.insert(priority_tab, i, prio)
        break
      end
    end

    if not table.contains(priority_tab, prio) then
      table.insert(priority_tab, prio)
    end
  end

  if skill.visible then
    for _, s in ipairs(skill.related_skills) do
      if (s.class == TriggerSkill) then
        ---@cast s TriggerSkill
        self:addTriggerSkill(s)
      end
    end
  end
end

---@param event TriggerEvent|integer|string
---@param target? ServerPlayer
---@param data? any data应该传入一个构造好的某某class实例
function GameLogic:trigger(event, target, data, refresh_only)
  local broken = false --self:triggerForLegacy(event, target, data, refresh_only)
  if broken then return broken end
  if not (type(event) == "table" and event:isSubclassOf(TriggerEvent)) then
    return broken
  end

  local event_obj = event:new(self.room, target, data)
  event_obj.refresh_only = refresh_only
  return event_obj:exec()
end

-- 此为启动事件管理器并启动第一个事件的初始函数
function GameLogic:start()
  local root_event = GameEvent.Game:create()

  self:pushEvent(root_event)

  -- 此时的协程：room.main_co
  -- 事件管理器协程，同时也是Game事件
  -- 当新事件想要exec时，就切回此处，由这里负责调度协程
  -- 一个事件结束后也切回此处，然后resume
  local co = coroutine.create(function() return root_event:main() end)
  root_event._co = co

  while true do
    -- 对于cleaner和正常事件，处理更后面来的
    local ne = self:getCurrentEvent()
    local ce = self:getCurrentCleaner()
    local e = ce and (ce.id >= ne.id and ce or ne) or ne

    if not e then -- 没有事件，按理说不应该，平局处理
      self.room:sendLog{
        type = "#NoEventDraw",
        toast = true,
      }
      self.room:gameOver("")
    end

    if e == ne and e.killed then
      e.interrupted = true
      self:clearEvent(e)
      coroutine.close(e._co)
      e.status = "dead"
      e = self:getCurrentCleaner()
    end

    -- ret, evt解释：
    -- * true, nil: 中止
    -- * false, nil: 正常结束
    -- * true, GameEvent: 中止直到某event
    -- * false, GameEvent: 未结束，插入新event
    -- 若jump_to不为nil，表示正在中断至某某事件
    local ret, evt = self:resumeEvent(e)
    if evt == nil then
      e.interrupted = ret
      self:clearEvent(e)
      coroutine.close(e._co)
      e.status = "dead"
    elseif ret == true then
      -- 遍历栈，将shutdown图中的事件全标记上killed
      -- 被标记killed的事件之后会自动结束并清理
      for i = self.game_event_stack.p, 1, -1 do
        local event = self.game_event_stack.t[i]
        event.killed = true
        if event == evt then break end
      end
    end
  end
end

---@param event GameEvent
function GameLogic:pushEvent(event)
  self.game_event_stack:push(event)

  self.current_event_id = self.current_event_id + 1
  event.id = self.current_event_id
  self.all_game_events[event.id] = event
  self.event_recorder[event.event] = self.event_recorder[event.event] or {}
  table.insert(self.event_recorder[event.event], event)
end

-- 一般来说从GameEvent:exec切回start再被start调用
-- 作用是启动新事件 都是结构差不多的函数
---@param event GameEvent
---@return boolean, GameEvent?
function GameLogic:resumeEvent(event)
  local ret, evt

  local co = event._co
  local resume_reason = "unknown"

  while true do
    local err, yield_result, extra_yield_result = coroutine.resume(co, resume_reason)

    if err == false then
      -- handle error, then break
      if not string.find(yield_result, "__manuallyBreak") then
        fk.qCritical(yield_result .. "\n" .. debug.traceback(co) ..
          "\n" .. self:dumpEventStack())
      end
      ret = true
      break
    end

    if yield_result == "__handleRequest" then
      -- yield to requestLoop
      -- handleRequest类的最后被ResumeRoom唤醒，接收原因
      resume_reason = coroutine.yield(yield_result, extra_yield_result)

    elseif type(yield_result) == "table" and yield_result.class
      and yield_result:isInstanceOf(GameEvent) then

      if extra_yield_result == "__newEvent" then
        ret, evt = false, yield_result
        break
      elseif extra_yield_result == "__breakEvent" then
        ret, evt = true, yield_result
        if event.event ~= GameEvent.ClearEvent then break end
      end

    elseif yield_result == "__breakEvent" then
      ret = true
      if event.event ~= GameEvent.ClearEvent then break end

    else
      ret = false
      event.exec_ret = yield_result
      break
    end
  end

  return ret, evt
end

---@return GameEvent
function GameLogic:getCurrentCleaner()
  return self.cleaner_stack.t[self.cleaner_stack.p]
end

-- 事件中的清理。
-- cleaner单独开协程运行，exitFunc须转到上个事件的协程内执行
-- 注意插入新event
---@param event GameEvent
function GameLogic:clearEvent(event)
  if event.event == GameEvent.ClearEvent then return end
  if event.status == "exiting" then return end
  event.status = "exiting"
  local ce = GameEvent.ClearEvent:create(event)
  ce.id = self.current_event_id
  local co = coroutine.create(function() return ce:main() end)
  ce._co = co
  self.cleaner_stack:push(ce)
end

---@return GameEvent
function GameLogic:getCurrentEvent()
  return self.game_event_stack.t[self.game_event_stack.p]
end

function GameLogic:getCurrentEventDepth()
  return self.game_event_stack.p
end

---@param eventType GameEvent
function GameLogic:getMostRecentEvent(eventType)
  return self:getCurrentEvent():findParent(eventType, true)
end

--- 如果当前事件刚好是技能生效事件，就返回那个技能名，否则返回空串。
---@return string|nil
function GameLogic:getCurrentSkillName()
  local skillEvent = self:getCurrentEvent()
  local ret = nil
  if skillEvent.event == GameEvent.SkillEffect then
    local _skill = skillEvent.data.skill
    local skill = _skill.main_skill and _skill.main_skill or _skill
    ret = skill.name
  end
  return ret
end

-- 在指定历史范围中找至多n个符合条件的事件
---@generic T: GameEvent
---@param eventType T @ 要查找的事件类型
---@param n integer @ 最多找多少个
---@param func fun(e: T): boolean? @ 过滤用的函数
---@param scope integer @ 查询历史范围，只能是当前阶段/回合/轮次
---@return T[] @ 找到的符合条件的所有事件，最多n个但不保证有n个
function GameLogic:getEventsOfScope(eventType, n, func, scope)
  scope = scope or Player.HistoryTurn
  local event = self:getCurrentEvent()
  local start_event ---@type GameEvent?
  if scope == Player.HistoryGame then
    start_event = self.all_game_events[1]
  elseif scope == Player.HistoryRound then
    start_event = event:findParent(GameEvent.Round, true)
  elseif scope == Player.HistoryTurn then
    start_event = event:findParent(GameEvent.Turn, true)
  elseif scope == Player.HistoryPhase then
    start_event = event:findParent(GameEvent.Phase, true)
  end
  if not start_event then return {} end
  return start_event:searchEvents(eventType, n, func)
end

-- 在指定历史范围中找符合条件的事件（逆序）
---@generic T: GameEvent
---@param eventType T @ 要查找的事件类型
---@param func fun(e: T): boolean? @ 过滤用的函数
---@param n integer @ 最多找多少个
---@param end_id? integer @ 查询历史范围：从最后的事件开始逆序查找直到id为end_id的事件（不含），默认当前事件的id
---@param scope? integer @ 查询历史范围：当有此参数时end_id参数失效，改为查找当前阶段/回合/轮次/游戏
---@return T[] @ 找到的符合条件的所有事件，最多n个但不保证有n个
function GameLogic:getEventsByRule(eventType, n, func, end_id, scope)
  if scope then
    local end_event ---@type GameEvent?
    if scope == Player.HistoryGame then
      end_id = 0
    elseif scope == Player.HistoryRound then
      end_event = self:getCurrentEvent():findParent(GameEvent.Round, true)
    elseif scope == Player.HistoryTurn then
      end_event = self:getCurrentEvent():findParent(GameEvent.Turn, true)
    elseif scope == Player.HistoryPhase then
      end_event = self:getCurrentEvent():findParent(GameEvent.Phase, true)
    end
    if end_event then
      end_id = end_event.id
    end
  end
  if end_id == nil then
    end_id = self:getCurrentEvent().id
  end
  local ret = {}
	local events = self.event_recorder[eventType] or Util.DummyTable
  for i = #events, 1, -1 do
    local e = events[i]
    if e.id <= end_id then break end
    if func(e) then
      table.insert(ret, e)
      if #ret >= n then break end
    end
  end
  return ret
end

---@return string?
function GameLogic:dumpEventStack()
  local top = self:getCurrentEvent()
  local i = self.game_event_stack.p
  if not top then return end

  local ret = "===== Start of event stack dump =====\n"

  repeat
    ret = ret .. tostring(top) .. "\n"

    top = top.parent
    i = i - 1
  until not top

  ret = ret .. "===== End of event stack dump =====\n"
  return ret
end

function GameLogic:dumpAllEvents(from, to)
  from = from or 1
  to = to or #self.all_game_events
  assert(from <= to)

  local indent = 0
  local tab = "  "
  for i = from, to, 1 do
    local v = self.all_game_events[i]
    if type(v) ~= "table" or not v:isInstanceOf(GameEvent) then
      indent = math.max(indent - 1, 0)
      -- v = "End"
      -- print(tab:rep(indent) .. string.format("#%d: %s", i, v))
    else
      print(tab:rep(indent) .. tostring(v))
      if v.id ~= v.end_id then
        indent = indent + 1
      end
    end
  end
end

function GameLogic:breakEvent(ret)
  coroutine.yield("__breakEvent", ret)
end

return GameLogic
