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
  room:doBroadcastNotify("StartGame", "")
  room:adjustSeats()

  self:chooseGenerals()

  self:buildPlayerCircle()
  self:broadcastGeneral()
  self:prepareDrawPile()
  self:attachSkillToPlayers()
  self:prepareForStart()

  self.room.game_started = true
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
  local lord_general = nil

  if lord ~= nil then
    room.current = lord
    local generals = Fk:getGeneralsRandomly(generalNum)
    for i = 1, #generals do
      generals[i] = generals[i].name
    end
    lord_general = room:askForGeneral(lord, generals, n)
    local deputy
    if type(lord_general) == "table" then
      deputy = lord_general[2]
      lord_general = lord_general[1]
    end

    room:setPlayerGeneral(lord, lord_general, true)
    if lord.kingdom == "god" or Fk.generals[lord_general].subkingdom then
      local allKingdoms = {}
      if lord.kingdom == "god" then
        allKingdoms = table.simpleClone(Fk.kingdoms)

        local exceptedKingdoms = { "god" }
        for _, kingdom in ipairs(exceptedKingdoms) do
          table.removeOne(allKingdoms, kingdom)
        end
      else
        local curGeneral = Fk.generals[lord_general]
        allKingdoms = { curGeneral.kingdom, curGeneral.subkingdom }
      end

      lord.kingdom = room:askForChoice(lord, allKingdoms, "AskForKingdom", "#ChooseInitialKingdom")
      room:broadcastProperty(lord, "kingdom")
    end
    room:broadcastProperty(lord, "general")
    room:setDeputyGeneral(lord, deputy)
    room:broadcastProperty(lord, "deputyGeneral")
  end

  local nonlord = room:getOtherPlayers(lord, true)
  local generals = Fk:getGeneralsRandomly(#nonlord * generalNum, nil, {lord_general})
  table.shuffle(generals)
  for _, p in ipairs(nonlord) do
    local arg = {}
    for i = 1, generalNum do
      table.insert(arg, table.remove(generals, 1).name)
    end
    p.request_data = json.encode{ arg, n }
    p.default_reply = table.random(arg, n)
  end

  room:notifyMoveFocus(nonlord, "AskForGeneral")
  room:doBroadcastRequest("AskForGeneral", nonlord)

  for _, p in ipairs(nonlord) do
    if p.general == "" and p.reply_ready then
      local generals = json.decode(p.client_reply)
      local general = generals[1]
      local deputy = generals[2]
      room:setPlayerGeneral(p, general, true, true)
      room:setDeputyGeneral(p, deputy)
    else
      room:setPlayerGeneral(p, p.default_reply[1], true, true)
      room:setDeputyGeneral(p, p.default_reply[2])
    end
    p.default_reply = ""
  end

  local specialKingdomPlayers = table.filter(nonlord, function(p)
    return p.kingdom == "god" or Fk.generals[p.general].subkingdom
  end)

  if #specialKingdomPlayers > 0 then
    local choiceMap = {}
    for _, p in ipairs(specialKingdomPlayers) do
      local allKingdoms = {}
      if p.kingdom == "god" then
        allKingdoms = table.simpleClone(Fk.kingdoms)

        local exceptedKingdoms = { "god" }
        for _, kingdom in ipairs(exceptedKingdoms) do
          table.removeOne(allKingdoms, kingdom)
        end
      else
        local curGeneral = Fk.generals[p.general]
        allKingdoms = { curGeneral.kingdom, curGeneral.subkingdom }
      end

      choiceMap[p.id] = allKingdoms

      local data = json.encode({ allKingdoms, "AskForKingdom", "#ChooseInitialKingdom" })
      p.request_data = data
    end

    room:notifyMoveFocus(nonlord, "AskForKingdom")
    room:doBroadcastRequest("AskForChoice", specialKingdomPlayers)

    for _, p in ipairs(specialKingdomPlayers) do
      local kingdomChosen
      if p.reply_ready then
        kingdomChosen = p.client_reply
      else
        kingdomChosen = choiceMap[p.id][1]
      end

      p.kingdom = kingdomChosen
      room:notifyProperty(p, p, "kingdom")
    end
  end
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
    p.maxHp = deputy and math.floor((deputy.maxHp + general.maxHp) / 2)
      or general.maxHp
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
---@param target ServerPlayer
---@param data any
function GameLogic:trigger(event, target, data, refresh_only)
  local room = self.room
  local broken = false
  local skills = self.skill_table[event] or {}
  local skills_to_refresh = self.refresh_skill_table[event] or {}
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
      local triggerables = table.filter(skills, function(skill)
        return skill.priority_table[event] == prio and
          skill:triggerable(event, target, player, data)
      end)

      local skill_names = table.map(triggerables, function(skill)
        return skill.name
      end)

      while #skill_names > 0 do
        local skill_name = prio <= 0 and table.random(skill_names) or
          room:askForChoice(player, skill_names, "trigger", "#choose-trigger")

        local skill = skill_name == "game_rule" and GameRule
          or Fk.skills[skill_name]

        local len = #skills
        broken = skill:trigger(event, target, player, data)

        table.insertTable(
          skill_names,
          table.map(table.filter(table.slice(skills, len - #skills), function(s)
            return
              s.priority_table[event] == prio and
              s:triggerable(event, target, player, data)
          end), function(s) return s.name end)
        )

        broken = broken or (event == fk.AskForPeaches
          and room:getPlayerById(data.who).hp > 0)

        if broken then break end
        table.removeOne(skill_names, skill_name)
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
    start_event = event:findParent(GameEvent.Round)
  elseif scope == Player.HistoryTurn then
    start_event = event:findParent(GameEvent.Turn)
  elseif scope == Player.HistoryPhase then
    start_event = event:findParent(GameEvent.Phase)
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
    if type(v) == "number" then
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
