-- SPDX-License-Identifier: GPL-3.0-or-later

---@class GameLogic: Object
---@field public room Room
---@field public skill_table table<Event, TriggerSkill[]>
---@field public skill_priority_table table<Event, number[]>
---@field public refresh_skill_table table<Event, TriggerSkill[]>
---@field public skills string[]
---@field public game_event_stack Stack
---@field public cleaner_stack Stack
---@field public role_table string[][]
---@field public all_game_events GameEvent[]
---@field public event_recorder table<GameEvent, GameEvent>
---@field public current_event_id integer
local GameLogic = class("GameLogic")

function GameLogic:initialize(room)
  self.room = room
  self.skill_table = {}   -- TriggerEvent --> TriggerSkill[]
  self.skill_priority_table = {}
  self.refresh_skill_table = {}
  self.skills = {}    -- skillName[]
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

  self.role_table = {
    { "lord" },
    { "lord", "rebel" },
    { "lord", "rebel", "renegade" },
    { "lord", "loyalist", "rebel", "renegade" },
    { "lord", "loyalist", "rebel", "rebel", "renegade" },
    { "lord", "loyalist", "rebel", "rebel", "rebel", "renegade" },
    { "lord", "loyalist", "loyalist", "rebel", "rebel", "rebel", "renegade" },
    { "lord", "loyalist", "loyalist", "rebel", "rebel", "rebel", "rebel", "renegade" },
  }
end

function GameLogic:run()
  -- default logic
  local room = self.room
  table.shuffle(self.room.players)
  self:assignRoles()
  self.room.game_started = true
  room:doBroadcastNotify("StartGame", "")
  room:adjustSeats()
  --[[ 因为未完工，在release版暂时不启用。
  for _, p in ipairs(room.players) do
    p.ai = SmartAI:new(p)
  end
  --]]
  self:chooseGenerals()

  self:buildPlayerCircle()
  self:broadcastGeneral()
  self:prepareDrawPile()
  self:attachSkillToPlayers()
  self:prepareForStart()

  self:action()
end

---@return boolean
local function execGameEvent(tp, ...)
  local event = tp:create(...)
  local _, ret = event:exec()
  return ret
end

function GameLogic:assignRoles()
  local room = self.room
  local n = #room.players
  local roles = self.role_table[n]
  table.shuffle(roles)

  for i = 1, n do
    local p = room.players[i]
    p.role = roles[i]
    if p.role == "lord" then
      p.role_shown = true
      room:broadcastProperty(p, "role")
    else
      room:notifyProperty(p, p, "role")
    end
  end
end

function GameLogic:chooseGenerals()
  local room = self.room
  local generalNum = room.settings.generalNum
  local n = room.settings.enableDeputy and 2 or 1
  local lord = room:getLord()
  local lord_generals = {}

  if lord ~= nil then
    room.current = lord
    local generals = room:getNGenerals(generalNum)
    lord_generals = room:askForGeneral(lord, generals, n)
    local lord_general, deputy
    if type(lord_generals) == "table" then
      deputy = lord_generals[2]
      lord_general = lord_generals[1]
    else
      lord_general = lord_generals
      lord_generals = {lord_general}
    end

    generals = table.filter(generals, function(g) return not table.contains(lord_generals, g) end)
    room:returnToGeneralPile(generals)

    room:prepareGeneral(lord, lord_general, deputy, true)

    room:askForChooseKingdom({lord})
  end

  local nonlord = room:getOtherPlayers(lord, true)
  local generals = table.random(room.general_pile, #nonlord * generalNum)
  for i, p in ipairs(nonlord) do
    local arg = table.slice(generals, (i - 1) * generalNum + 1, i * generalNum + 1)
    p.request_data = json.encode{ arg, n }
    p.default_reply = table.random(arg, n)
  end

  room:notifyMoveFocus(nonlord, "AskForGeneral")
  room:doBroadcastRequest("AskForGeneral", nonlord)

  for _, p in ipairs(nonlord) do
    local general, deputy
    if p.general == "" and p.reply_ready then
      local general_ret = json.decode(p.client_reply)
      general = general_ret[1]
      deputy = general_ret[2]
    else
      general = p.default_reply[1]
      deputy = p.default_reply[2]
    end
    room:findGeneral(general)
    room:findGeneral(deputy)
    room:prepareGeneral(p, general, deputy)
    p.default_reply = ""
  end

  room:askForChooseKingdom(nonlord)
end

function GameLogic:buildPlayerCircle()
  local room = self.room
  local players = room.players
  room.alive_players = {table.unpack(players)}
  for i = 1, #players - 1 do
    players[i].next = players[i + 1]
  end
  players[#players].next = players[1]
end

function GameLogic:broadcastGeneral()
  local room = self.room
  local players = room.players

  for _, p in ipairs(players) do
    assert(p.general ~= "")
    local general = Fk.generals[p.general]
    local deputy = Fk.generals[p.deputyGeneral]
    p.maxHp = p:getGeneralMaxHp()
    p.hp = deputy and math.floor((deputy.hp + general.hp) / 2) or general.hp
    p.shield = math.min(general.shield + (deputy and deputy.shield or 0), 5)
    -- TODO: setup AI here

    local changer = Fk.game_modes[room.settings.gameMode]:getAdjustedProperty(p)
    if changer then
      for key, value in pairs(changer) do
        p[key] = value
      end
    end
    local fixMaxHp = Fk.generals[p.general].fixMaxHp
    local deputyFix = Fk.generals[p.deputyGeneral] and Fk.generals[p.deputyGeneral].fixMaxHp
    if deputyFix then
      fixMaxHp = fixMaxHp and math.min(fixMaxHp, deputyFix) or deputyFix
    end
    if fixMaxHp then
      p.maxHp = fixMaxHp
    end
    p.hp = math.min(p.maxHp, p.hp)

    room:broadcastProperty(p, "general")
    room:broadcastProperty(p, "deputyGeneral")
    room:broadcastProperty(p, "kingdom")
    room:broadcastProperty(p, "maxHp")
    room:broadcastProperty(p, "hp")
    room:broadcastProperty(p, "shield")
  end
end

function GameLogic:prepareDrawPile()
  local room = self.room
  local allCardIds = Fk:getAllCardIds()

  for i = #allCardIds, 1, -1 do
    if Fk:getCardById(allCardIds[i]).is_derived then
      local id = allCardIds[i]
      table.removeOne(allCardIds, id)
      table.insert(room.void, id)
      room:setCardArea(id, Card.Void, nil)
    end
  end

  table.shuffle(allCardIds)
  room.draw_pile = allCardIds
  for _, id in ipairs(room.draw_pile) do
    self.room:setCardArea(id, Card.DrawPile, nil)
  end
end

function GameLogic:attachSkillToPlayers()
  local room = self.room
  local players = room.players

  local addRoleModSkills = function(player, skillName)
    local skill = Fk.skills[skillName]
    if not skill then
      fk.qCritical("Skill: "..skillName.." doesn't exist!")
      return
    end
    if skill.lordSkill and (player.role ~= "lord" or #room.players < 5) then
      return
    end

    if #skill.attachedKingdom > 0 and not table.contains(skill.attachedKingdom, player.kingdom) then
      return
    end

    room:handleAddLoseSkills(player, skillName, nil, false)
  end
  for _, p in ipairs(room.alive_players) do
    local skills = Fk.generals[p.general].skills
    for _, s in ipairs(skills) do
      addRoleModSkills(p, s.name)
    end
    for _, sname in ipairs(Fk.generals[p.general].other_skills) do
      addRoleModSkills(p, sname)
    end

    local deputy = Fk.generals[p.deputyGeneral]
    if deputy then
      skills = deputy.skills
      for _, s in ipairs(skills) do
        addRoleModSkills(p, s.name)
      end
      for _, sname in ipairs(deputy.other_skills) do
        addRoleModSkills(p, sname)
      end
    end
  end
end

function GameLogic:prepareForStart()
  local room = self.room
  local players = room.players

  self:addTriggerSkill(GameRule)
  for _, trig in ipairs(Fk.global_trigger) do
    self:addTriggerSkill(trig)
  end

  self.room:sendLog{ type = "$GameStart" }
end

function GameLogic:action()
  self:trigger(fk.GamePrepared)
  local room = self.room

  execGameEvent(GameEvent.DrawInitial)

  while true do
    execGameEvent(GameEvent.Round)
    if room.game_finished then break end
  end
end

---@param skill TriggerSkill
function GameLogic:addTriggerSkill(skill)
  if skill == nil or table.contains(self.skills, skill.name) then
    return
  end

  table.insert(self.skills, skill.name)

  for _, event in ipairs(skill.refresh_events) do
    if self.refresh_skill_table[event] == nil then
      self.refresh_skill_table[event] = {}
    end
    table.insert(self.refresh_skill_table[event], skill)
  end

  for _, event in ipairs(skill.events) do
    if self.skill_table[event] == nil then
      self.skill_table[event] = {}
    end
    table.insert(self.skill_table[event], skill)

    if self.skill_priority_table[event] == nil then
      self.skill_priority_table[event] = {}
    end

    local priority_tab = self.skill_priority_table[event]
    local prio = skill.priority_table[event]
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

    if not table.contains(self.skill_priority_table[event],
      skill.priority_table[event]) then

      table.insert(self.skill_priority_table[event],
        skill.priority_table[event])
    end
  end

  if skill.visible then
    if (Fk.related_skills[skill.name] == nil) then return end
    for _, s in ipairs(Fk.related_skills[skill.name]) do
      if (s.class == TriggerSkill) then
        self:addTriggerSkill(s)
      end
    end
  end
end

---@param event Event
---@param target? ServerPlayer
---@param data? any
function GameLogic:trigger(event, target, data, refresh_only)
  local room = self.room
  local broken = false
  local skills = self.skill_table[event] or {}
  local skills_to_refresh = self.refresh_skill_table[event] or Util.DummyTable
  local _target = room.current -- for iteration
  local player = _target
  local cur_event = self:getCurrentEvent() or {}
  -- 如果当前事件被杀，就强制只refresh
  -- 因为被杀的事件再进行正常trigger只可能在cleaner和exit了
  refresh_only = refresh_only or cur_event.killed

  if #skills_to_refresh > 0 then repeat do
    -- refresh skills. This should not be broken
    for _, skill in ipairs(skills_to_refresh) do
      if skill:canRefresh(event, target, player, data) then
        skill:refresh(event, target, player, data)
      end
    end
    player = player.next
  end until player == _target end

  if #skills == 0 or refresh_only then return end

  local prio_tab = self.skill_priority_table[event]
  local prev_prio = math.huge

  for _, prio in ipairs(prio_tab) do
    if broken then break end
    if prio >= prev_prio then
      -- continue
      goto trigger_loop_continue
    end

    repeat do
      local invoked_skills = {}
      local filter_func = function(skill)
        return skill.priority_table[event] == prio and
          not table.contains(invoked_skills, skill) and
          skill:triggerable(event, target, player, data)
      end

      local skill_names = table.map(table.filter(skills, filter_func), Util.NameMapper)

      while #skill_names > 0 do
        local skill_name = prio <= 0 and table.random(skill_names) or
          room:askForChoice(player, skill_names, "trigger", "#choose-trigger")

        local skill = skill_name == "game_rule" and GameRule
          or Fk.skills[skill_name]

        table.insert(invoked_skills, skill)
        broken = skill:trigger(event, target, player, data)
        skill_names = table.map(table.filter(skills, filter_func), Util.NameMapper)

        broken = broken or (event == fk.AskForPeaches
          and room:getPlayerById(data.who).hp > 0) or
          (table.contains({fk.PreDamage, fk.DamageCaused, fk.DamageInflicted}, event) and data.damage < 1) or
          cur_event.killed

        if broken then break end
      end

      if broken then break end

      player = player.next
    end until player == _target

    prev_prio = prio
    ::trigger_loop_continue::
  end

  return broken
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

    if e == ne and e.killed then
      e.interrupted = true
      self:clearEvent(e)
      coroutine.close(e._co)
      e.status = "dead"
      e = self:getCurrentCleaner()
    end

    if not e then -- 没有事件，按理说不应该，平局处理
      self.room:sendLog{
        type = "#NoEventDraw",
        toast = true,
      }
      self.room:gameOver("")
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
function GameLogic:resumeEvent(event, ...)
  local ret, evt

  local co = event._co

  while true do
    local err, yield_result, extra_yield_result = coroutine.resume(co, ...)

    if err == false then
      -- handle error, then break
      if not string.find(yield_result, "__manuallyBreak") then
        fk.qCritical(yield_result .. "\n" .. debug.traceback(co))
      end
      ret = true
      break
    end

    if yield_result == "__handleRequest" then
      -- yield to requestLoop
      coroutine.yield(yield_result, extra_yield_result)

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

---@param eventType GameEvent
function GameLogic:getMostRecentEvent(eventType)
  return self:getCurrentEvent():findParent(eventType, true)
end

--- 如果当前事件刚好是技能生效事件，就返回那个技能名，否则返回空串。
function GameLogic:getCurrentSkillName()
  local skillEvent = self:getCurrentEvent()
  local ret = ""
  if skillEvent.event == GameEvent.SkillEffect then
    local _, _, _skill = table.unpack(skillEvent.data)
    local skill = _skill.main_skill and _skill.main_skill or _skill
    ret = skill.name
  end
  return ret
end

-- 在指定历史范围中找至多n个符合条件的事件
---@param eventType GameEvent @ 要查找的事件类型
---@param n integer @ 最多找多少个
---@param func fun(e: GameEvent): boolean @ 过滤用的函数
---@param scope integer @ 查询历史范围，只能是当前阶段/回合/轮次
---@return GameEvent[] @ 找到的符合条件的所有事件，最多n个但不保证有n个
function GameLogic:getEventsOfScope(eventType, n, func, scope)
  scope = scope or Player.HistoryTurn
  local event = self:getCurrentEvent()
  local start_event ---@type GameEvent
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
---@param eventType integer @ 要查找的事件类型
---@param func fun(e: GameEvent): boolean @ 过滤用的函数
---@param n integer @ 最多找多少个
---@param end_id integer @ 查询历史范围：从最后的事件开始逆序查找直到id为end_id的事件（不含）
---@return GameEvent[] @ 找到的符合条件的所有事件，最多n个但不保证有n个
function GameLogic:getEventsByRule(eventType, n, func, end_id)
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


--- 获取实际的伤害事件
---@param n integer @ 最多找多少个
---@param func fun(e: GameEvent): boolean @ 过滤用的函数
---@param scope? integer @ 查询历史范围，只能是当前阶段/回合/轮次
---@param end_id? integer @ 查询历史范围：从最后的事件开始逆序查找直到id为end_id的事件（不含）
---@return GameEvent[] @ 找到的符合条件的所有事件，最多n个但不保证有n个
function GameLogic:getActualDamageEvents(n, func, scope, end_id)
  if not end_id then
    scope = scope or Player.HistoryTurn
  end

  n = n or 1
  func = func or Util.TrueFunc

  local eventType = GameEvent.Damage
  local ret = {}
  local endIdRecorded
  local tempEvents = {}

  local addTempEvents = function(reverse)
    if #tempEvents > 0 and #ret < n then
      table.sort(tempEvents, function(a, b)
        if reverse then
          return a.data[1].dealtRecorderId > b.data[1].dealtRecorderId
        else
          return a.data[1].dealtRecorderId < b.data[1].dealtRecorderId
        end
      end)

      for _, e in ipairs(tempEvents) do
        table.insert(ret, e)
        if #ret >= n then return true end
      end
    end

    endIdRecorded = nil
    tempEvents = {}

    return false
  end

  if scope then
    local event = self:getCurrentEvent()
    local start_event ---@type GameEvent
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

    local events = self.event_recorder[eventType] or Util.DummyTable
    local from = start_event.id
    local to = start_event.end_id
    if math.abs(to) == 1 then to = #self.all_game_events end

    for _, v in ipairs(events) do
      local damageStruct = v.data[1]
      if damageStruct.dealtRecorderId then
        if endIdRecorded and v.id > endIdRecorded then
          local result = addTempEvents()
          if result then
            return ret
          end
        end

        if v.id >= from and v.id <= to then
          if not endIdRecorded and v.end_id > -1 and v.end_id > v.id then
            endIdRecorded = v.end_id
          end

          if func(v) then
            if endIdRecorded then
              table.insert(tempEvents, v)
            else
              table.insert(ret, v)
            end
          end
        end
        if #ret >= n then break end
      end
    end

    addTempEvents()
  else
    local events = self.event_recorder[eventType] or Util.DummyTable

    for i = #events, 1, -1 do
      local e = events[i]
      if e.id <= end_id then break end

      local damageStruct = e.data[1]
      if damageStruct.dealtRecorderId then
        if e.end_id == -1 or (endIdRecorded and endIdRecorded > e.end_id) then
          local result = addTempEvents(true)
          if result then
            return ret
          end

          if func(e) then
            table.insert(ret, e)
          end
        else
          endIdRecorded = e.end_id
          if func(e) then
            table.insert(tempEvents, e)
          end
        end

        if #ret >= n then break end
      end
    end

    addTempEvents(true)
  end

  return ret
end

--检测最近的伤害事件是否由执行牌的效果触发，即通常描述的使用牌对目标角色造成伤害
---@param is_exact? bool @ 是否进一步判定使用者和来源是否一致（默认为true）
---@return bool
function GameLogic:damageByCardEffect(is_exact)
  is_exact = (is_exact == nil) and true or is_exact
  local d_event = self:getCurrentEvent():findParent(GameEvent.Damage, true)
  if d_event == nil then return false end
  local damage = d_event.data[1]
  if damage.chain or damage.card == nil then return false end
  local c_event = d_event:findParent(GameEvent.CardEffect, false, 2)
  if c_event == nil then return false end
  return damage.card == c_event.data[1].card and
  (not is_exact or d_event.data[1].from.id == c_event.data[1].from)
end

function GameLogic:dumpEventStack(detailed)
  local top = self:getCurrentEvent()
  local i = self.game_event_stack.p
  local inspect = p
  if not top then return end

  print("===== Start of event stack dump =====")
  if not detailed then print("") end

  repeat
    local printable_data
    if type(top.data) ~= "table" then
      printable_data = top.data
    else
      printable_data = table.cloneWithoutClass(top.data)
    end

    if not detailed then
      print("Stack level #" .. i .. ": " .. tostring(top))
    else
      print("\nStack level #" .. i .. ":")
      inspect{
        eventId = GameEvent:translate(top.event),
        data = printable_data or "nil",
      }
    end

    top = top.parent
    i = i - 1
  until not top

  print("\n===== End of event stack dump =====")
end

function GameLogic:dumpAllEvents(from, to)
  from = from or 1
  to = to or #self.all_game_events
  assert(from <= to)

  local indent = 0
  local tab = "  "
  for i = from, to, 1 do
    local v = self.all_game_events[i]
    if type(v) ~= "table" then
      indent = math.max(indent - 1, 0)
      -- v = "End"
      -- print(tab:rep(indent) .. string.format("#%d: %s", i, v))
    else
      print(tab:rep(indent) .. string.format("%s", tostring(v)))
      if v.id ~= v.end_id then
        indent = indent + 1
      end
    end
  end
end

function GameLogic:breakEvent(ret)
  coroutine.yield("__breakEvent", ret)
end

function GameLogic:breakTurn()
  local event = self:getCurrentEvent():findParent(GameEvent.Turn)
  if not event then return end
  event:shutdown()
end

return GameLogic
