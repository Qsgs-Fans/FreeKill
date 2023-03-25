---@class GameLogic: Object
---@field public room Room
---@field public skill_table table<Event, TriggerSkill[]>
---@field public refresh_skill_table table<Event, TriggerSkill[]>
---@field public skills string[]
---@field public event_stack Stack
---@field public game_event_stack Stack
---@field public role_table string[][]
local GameLogic = class("GameLogic")

function GameLogic:initialize(room)
  self.room = room
  self.skill_table = {}   -- TriggerEvent --> TriggerSkill[]
  self.refresh_skill_table = {}
  self.skills = {}    -- skillName[]
  self.event_stack = Stack:new()
  self.game_event_stack = Stack:new()

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
  table.shuffle(self.room.players)
  self:assignRoles()
  self.room:adjustSeats()

  self:chooseGenerals()
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
  local function setPlayerGeneral(player, general)
    if Fk.generals[general] == nil then return end
    player.general = general
    player.gender = Fk.generals[general].gender
    self.room:notifyProperty(player, player, "general")
    self.room:broadcastProperty(player, "gender")
  end
  local lord = room:getLord()
  local lord_general = nil
  if lord ~= nil then
    room.current = lord
    local generals = Fk:getGeneralsRandomly(generalNum)
    for i = 1, #generals do
      generals[i] = generals[i].name
    end
    lord_general = room:askForGeneral(lord, generals)
    setPlayerGeneral(lord, lord_general)
    room:broadcastProperty(lord, "general")
  end

  local nonlord = room:getOtherPlayers(lord, true)
  local generals = Fk:getGeneralsRandomly(#nonlord * generalNum, nil, {lord_general})
  table.shuffle(generals)
  for _, p in ipairs(nonlord) do
    local arg = {}
    for i = 1, generalNum do
      table.insert(arg, table.remove(generals, 1).name)
    end
    p.request_data = json.encode(arg)
    p.default_reply = arg[1]
  end

  room:notifyMoveFocus(nonlord, "AskForGeneral")
  room:doBroadcastRequest("AskForGeneral", nonlord)
  for _, p in ipairs(nonlord) do
    if p.general == "" and p.reply_ready then
      local general = json.decode(p.client_reply)[1]
      setPlayerGeneral(p, general)
    else
      setPlayerGeneral(p, p.default_reply)
    end
    p.default_reply = ""
  end
end

function GameLogic:prepareForStart()
  local room = self.room
  local players = room.players
  room.alive_players = {table.unpack(players)}
  for i = 1, #players - 1 do
    players[i].next = players[i + 1]
  end
  players[#players].next = players[1]

  for _, p in ipairs(players) do
    assert(p.general ~= "")
    local general = Fk.generals[p.general]
    p.maxHp = general.maxHp
    p.hp = general.hp
    -- TODO: setup AI here

    if p.role ~= "lord" then
      room:broadcastProperty(p, "general")
    elseif #players >= 5 then
      p.maxHp = p.maxHp + 1
      p.hp = p.hp + 1
    end
    room:broadcastProperty(p, "maxHp")
    room:broadcastProperty(p, "hp")

    -- TODO: add skills to player
  end

  local allCardIds = Fk:getAllCardIds()
  table.shuffle(allCardIds)
  room.draw_pile = allCardIds
  for _, id in ipairs(room.draw_pile) do
    self.room:setCardArea(id, Card.DrawPile, nil)
  end

  for _, p in ipairs(room.alive_players) do
    local skills = Fk.generals[p.general].skills
    for _, s in ipairs(skills) do
      room:handleAddLoseSkills(p, s.name, nil, false)
    end
    for _, sname in ipairs(Fk.generals[p.general].other_skills) do
      room:handleAddLoseSkills(p, sname, nil, false)
    end
  end

  self:addTriggerSkill(GameRule)
  for _, trig in ipairs(Fk.global_trigger) do
    self:addTriggerSkill(trig)
  end

  self.room:sendLog{ type = "$GameStart" }
end

function GameLogic:action()
  self:trigger(fk.GameStart)
  local room = self.room

  execGameEvent(GameEvent.DrawInitial)

  while true do
    execGameEvent(GameEvent.Turn)
    if room.game_finished then break end
    room.current = room.current:getNextAlive()
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
function GameLogic:trigger(event, target, data)
  local room = self.room
  local broken = false
  local skills = self.skill_table[event] or {}
  local skills_to_refresh = self.refresh_skill_table[event] or {}
  local _target = target or room.current -- for iteration
  local player = _target

  self.event_stack:push({event, target, data})

  repeat do
    -- refresh skills. This should not be broken
    for _, skill in ipairs(skills_to_refresh) do
      if skill:canRefresh(event, target, player, data) then
        skill:refresh(event, target, player, data)
      end
    end
    player = player.next
  end until player == _target

  ---@param a TriggerSkill
  ---@param b TriggerSkill
  local compare_func = function (a, b)
    return a.priority_table[event] > b.priority_table[event]
  end
  table.sort(skills, compare_func)

  repeat do
    local triggerable_skills = {}   ---@type table<number, TriggerSkill[]>
    local priority_table = {}     ---@type number[]
    for _, skill in ipairs(skills) do
      if skill:triggerable(event, target, player, data) then
        local priority = skill.priority_table[event]
        if triggerable_skills[priority] == nil then
          triggerable_skills[priority] = {}
        end
        table.insert(triggerable_skills[priority], skill)
        if not table.contains(priority_table, priority) then
          table.insert(priority_table, priority)
        end
      end
    end

    for _, priority in ipairs(priority_table) do
      local triggerables = triggerable_skills[priority]
      local skill_names = {}     ---@type string[]
      for _, skill in ipairs(triggerables) do
        table.insert(skill_names, skill.name)
      end

      while #skill_names > 0 do
        local skill_name = room:askForChoice(player, skill_names, "trigger", "#choose-trigger")
        local skill = triggerables[table.indexOf(skill_names, skill_name)]
        broken = skill:trigger(event, target, player, data)
        if broken then break end
        table.removeOne(skill_names, skill_name)
        table.removeOne(triggerables, skill)
      end
    end

    if broken then break end

    player = player.next
  end until player == _target

  self.event_stack:pop()
  return broken
end

function GameLogic:getCurrentEvent()
  return self.game_event_stack.t[self.game_event_stack.p]
end

function GameLogic:breakEvent(ret)
  coroutine.yield("__breakEvent", ret)
end

return GameLogic
