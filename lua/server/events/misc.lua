-- SPDX-License-Identifier: GPL-3.0-or-later

GameEvent.functions[GameEvent.ChangeProperty] = function(self)
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
    local originalSkills = originalGeneral and originalGeneral:getSkillNameList() or Util.DummyTable
    table.insertTableIfNeed(skills, table.map(originalSkills, function(e)
      return "-" .. e
    end))
    local newGeneral = Fk.generals[data.general] or Fk.generals["blank_shibing"]
    for _, name in ipairs(newGeneral:getSkillNameList()) do
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

  if data.deputyGeneral and data.deputyGeneral ~= "" and data.deputyGeneral ~= player.deputyGeneral then
    local originalDeputy = Fk.generals[player.deputyGeneral] or Fk.generals["blank_shibing"]
    local originalSkills = originalDeputy and originalDeputy:getSkillNameList() or Util.DummyTable
    table.insertTableIfNeed(skills, table.map(originalSkills, function(e)
      return "-" .. e
    end))
    local newDeputy = Fk.generals[data.deputyGeneral] or Fk.generals["blank_shibing"]
    for _, name in ipairs(newDeputy:getSkillNameList()) do
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
