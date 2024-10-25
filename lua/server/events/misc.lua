-- SPDX-License-Identifier: GPL-3.0-or-later

---@class MiscEventWrappers: Object
local MiscEventWrappers = {} -- mixin

---@class GameEvent.Game : GameEvent
local Game = GameEvent:subclass("GameEvent.Game")
function Game:main()
  self.room.logic:run()
end

---@class GameEvent.ChangeProperty : GameEvent
local ChangeProperty = GameEvent:subclass("GameEvent.Game")
function ChangeProperty:main()
  local data = table.unpack(self.data)
  local room = self.room
  local player = data.from
  local logic = room.logic
  logic:trigger(fk.BeforePropertyChange, player, data)

  data.sendLog = data.sendLog or false
  local skills = {}
  if logic:trigger(fk.PropertyChange, player, data) then
    logic:breakEvent()
  end

  if data.general and data.general ~= "" and data.general ~= player.general then
    local originalGeneral = Fk.generals[player.general] or Fk.generals["blank_shibing"]
    local originalSkills = originalGeneral and originalGeneral:getSkillNameList(true) or Util.DummyTable
    table.insertTableIfNeed(skills, table.map(originalSkills, function(e)
      return "-" .. e
    end))
    local newGeneral = Fk.generals[data.general] or Fk.generals["blank_shibing"]
    for _, name in ipairs(newGeneral:getSkillNameList(data.isLord)) do
      local s = Fk.skills[name]
      if not s.relate_to_place or s.relate_to_place == "m" then
        table.insertIfNeed(skills, name)
      end
    end
    if data.sendLog then
      room:sendLog{
        type = "#ChangeHero",
        from = player.id,
        arg = player.general,
        arg2 = data.general,
        arg3 = "mainGeneral",
      }
    end
    data.results["generalChange"] = {player.general, data.general}
    room:setPlayerProperty(player, "general", data.general)
  end

  if data.deputyGeneral and data.deputyGeneral ~= player.deputyGeneral then
    local originalDeputy = Fk.generals[player.deputyGeneral] or Fk.generals["blank_shibing"]
    local originalSkills = originalDeputy and originalDeputy:getSkillNameList(true) or Util.DummyTable
    table.insertTableIfNeed(skills, table.map(originalSkills, function(e)
      return "-" .. e
    end))

    if data.deputyGeneral ~= "" then
      local newDeputy = Fk.generals[data.deputyGeneral] or Fk.generals["blank_shibing"]
      for _, name in ipairs(newDeputy:getSkillNameList(data.isLord)) do
        local s = Fk.skills[name]
        if not s.relate_to_place or s.relate_to_place == "d" then
          table.insertIfNeed(skills, name)
        end
      end

      if data.sendLog then
        room:sendLog{
          type = "#ChangeHero",
          from = player.id,
          arg = player.deputyGeneral,
          arg2 = data.deputyGeneral,
          arg3 = "deputyGeneral",
        }
      end
    end

    data.results["deputyChange"] = {player.deputyGeneral, data.deputyGeneral}
    room:setPlayerProperty(player, "deputyGeneral", data.deputyGeneral)
  end

  if data.gender and data.gender ~= player.gender then
    data.results["genderChange"] = {player.gender, data.gender}
    room:setPlayerProperty(player, "gender", data.gender)
  end

  if data.kingdom and data.kingdom ~= "" and data.kingdom ~= player.kingdom then
    if data.sendLog then
      room:sendLog{
        type = "#ChangeKingdom",
        from = player.id,
        arg = player.kingdom,
        arg2 = data.kingdom,
      }
    end
    data.results["kingdomChange"] = {player.kingdom, data.kingdom}
    room:setPlayerProperty(player, "kingdom", data.kingdom)
  end

  for _, s in ipairs(Fk.generals[player.general].skills) do
    if #s.attachedKingdom > 0 then
      if table.contains(s.attachedKingdom, player.kingdom) then
        table.insertIfNeed(skills, s.name)
      else
        if table.contains(skills, s.name) then
          table.removeOne(skills, s.name)
        else
          table.insertIfNeed(skills, "-"..s.name)
        end
      end
    end
  end
  if player.deputyGeneral ~= "" then
    for _, s in ipairs(Fk.generals[player.deputyGeneral].skills) do
      if #s.attachedKingdom > 0 then
        if table.contains(s.attachedKingdom, player.kingdom) then
          table.insertIfNeed(skills, s.name)
        else
          if table.contains(skills, s.name) then
            table.removeOne(skills, s.name)
          else
            table.insertIfNeed(skills, "-"..s.name)
          end
        end
      end
    end
  end
  room:handleAddLoseSkills(player, table.concat(skills, "|"), nil, false, false)

  logic:trigger(fk.AfterPropertyChange, player, data)
end

---@param player ServerPlayer @ 要换将的玩家
---@param new_general string @ 要变更的武将，若不存在则变身为孙策，孙策不存在变身为士兵
---@param full? boolean @ 是否血量满状态变身
---@param isDeputy? boolean @ 是否变的是副将
---@param sendLog? boolean @ 是否发Log
---@param maxHpChange? boolean @ 是否改变体力上限，默认改变
function MiscEventWrappers:changeHero(player, new_general, full, isDeputy, sendLog, maxHpChange, kingdomChange)
  local new = Fk.generals[new_general] or Fk.generals["sunce"] or Fk.generals["blank_shibing"]

  kingdomChange = (kingdomChange == nil) and true or kingdomChange
  local kingdom = (isDeputy or not kingdomChange) and player.kingdom or new.kingdom
  if not isDeputy and kingdomChange then
    local allKingdoms = {}
    if new.subkingdom then
      allKingdoms = { new.kingdom, new.subkingdom }
    else
      allKingdoms = Fk:getKingdomMap(new.kingdom)
    end
    if #allKingdoms > 0 then
      kingdom = self:askForChoice(player, allKingdoms, "AskForKingdom", "#ChooseInitialKingdom")
    end
  end

  ChangeProperty:create({
    from = player,
    general = not isDeputy and new_general or nil,
    deputyGeneral = isDeputy and new_general or nil,
    gender = isDeputy and player.gender or new.gender,
    kingdom = kingdom,
    sendLog = sendLog,
    results = {},
  }):exec()

  maxHpChange = (maxHpChange == nil) and true or maxHpChange
  if maxHpChange then
    self:setPlayerProperty(player, "maxHp", player:getGeneralMaxHp())
  end
  if full or player.hp > player.maxHp then
    self:setPlayerProperty(player, "hp", player.maxHp)
  end
end

---@param player ServerPlayer @ 要变更势力的玩家
---@param kingdom string @ 要变更的势力
---@param sendLog? boolean @ 是否发Log
function MiscEventWrappers:changeKingdom(player, kingdom, sendLog)
  if kingdom == player.kingdom then return end
  sendLog = sendLog or false

  ChangeProperty:create({
    from = player,
    kingdom = kingdom,
    sendLog = sendLog,
    results = {},
  }):exec()
end

---@class GameEvent.ClearEvent : GameEvent
local ClearEvent = GameEvent:subclass("GameEvent.ClearEvent")
function ClearEvent:main()
  local event = self.data[1]
  local logic = self.room.logic
  -- 不可中断
  Pcall(event.clear, event)
  for _, f in ipairs(event.extra_clear) do
    if type(f) == "function" then Pcall(f, event) end
  end

  -- cleaner顺利执行完了，出栈吧
  local end_id = logic.current_event_id + 1
  if event.id ~= end_id - 1 then
    logic.all_game_events[end_id] = event.event
    logic.current_event_id = end_id
    event.end_id = end_id
  else
    event.end_id = event.id
  end

  logic.game_event_stack:pop()
  logic.cleaner_stack:pop()
end

return { Game, ChangeProperty, ClearEvent, MiscEventWrappers }
