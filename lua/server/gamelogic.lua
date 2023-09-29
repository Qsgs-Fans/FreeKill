-- SPDX-License-Identifier: GPL-3.0-or-later

---@class GameLogic: Object
---@field public room Room
---@field public skill_table table<Event, TriggerSkill[]>
---@field public skill_priority_table table<Event, number[]>
---@field public refresh_skill_table table<Event, TriggerSkill[]>
---@field public skills string[]
---@field public game_event_stack Stack
---@field public role_table string[][]
---@field public all_game_events GameEvent[]
---@field public event_recorder table<integer, GameEvent>
---@field public current_event_id integer
local GameLogic = class("GameLogic")

function GameLogic:initialize(room)
  self.room = room
  self.skill_table = {}   -- TriggerEvent --> TriggerSkill[]
  self.skill_priority_table = {}
  self.refresh_skill_table = {}
  self.skills = {}    -- skillName[]
  self.game_event_stack = Stack:new()
  self.all_game_events = {}
  self.event_recorder = {}
  self.current_event_id = 0

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

  self:chooseGenerals()

  self:buildPlayerCircle()
  self:broadcastGeneral()
  self:prepareDrawPile()
  self:attachSkillToPlayers()
  self:prepareForStart()

  self:action()
end

local function execGameEvent(type, ...)
  local event = GameEvent:new(type, ...)
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

    room:setPlayerGeneral(lord, lord_general, true)
    room:askForChooseKingdom({lord})
    room:broadcastProperty(lord, "general")
    room:broadcastProperty(lord, "kingdom")
    room:setDeputyGeneral(lord, deputy)
    room:broadcastProperty(lord, "deputyGeneral")
  end

  local nonlord = room:getOtherPlayers(lord, true)
  local generals = room:getNGenerals(#nonlord * generalNum)
  table.shuffle(generals)
  for i, p in ipairs(nonlord) do
    local arg = table.slice(generals, (i - 1) * generalNum + 1, i * generalNum + 1)
    p.request_data = json.encode{ arg, n }
    p.default_reply = table.random(arg, n)
  end

  room:notifyMoveFocus(nonlord, "AskForGeneral")
  room:doBroadcastRequest("AskForGeneral", nonlord)

  local selected = {}
  for _, p in ipairs(nonlord) do
    if p.general == "" and p.reply_ready then
      local general_ret = json.decode(p.client_reply)
      local general = general_ret[1]
      local deputy = general_ret[2]
      table.insertTableIfNeed(selected, general_ret)
      room:setPlayerGeneral(p, general, true, true)
      room:setDeputyGeneral(p, deputy)
    else
      room:setPlayerGeneral(p, p.default_reply[1], true, true)
      room:setDeputyGeneral(p, p.default_reply[2])
    end
    p.default_reply = ""
  end

  generals = table.filter(generals, function(g) return not table.contains(selected, g) end)
  room:returnToGeneralPile(generals)

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

    if p.role ~= "lord" then
      room:broadcastProperty(p, "general")
      room:broadcastProperty(p, "kingdom")
      room:broadcastProperty(p, "deputyGeneral")
    elseif #players >= 5 then
      p.maxHp = p.maxHp + 1
      p.hp = p.hp + 1
    end
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
---@param target ServerPlayer|nil
---@param data any|nil
function GameLogic:trigger(event, target, data, refresh_only)
  local room = self.room
  local broken = false
  local skills = self.skill_table[event] or {}
  local skills_to_refresh = self.refresh_skill_table[event] or Util.DummyTable
  local _target = room.current -- for iteration
  local player = _target

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
          and room:getPlayerById(data.who).hp > 0)

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

---@return GameEvent
function GameLogic:getCurrentEvent()
  return self.game_event_stack.t[self.game_event_stack.p]
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
---@param eventType integer @ 要查找的事件类型
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

  return start_event:searchEvents(eventType, n, func)
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
  event:shutdown()
end

return GameLogic
