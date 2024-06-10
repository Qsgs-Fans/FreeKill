-- SPDX-License-Identifier: GPL-3.0-or-later

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

return { Game, ChangeProperty, ClearEvent }
