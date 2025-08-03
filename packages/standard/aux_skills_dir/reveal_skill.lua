local revealSkill = fk.CreateSkill{
  name = "reveal_skill&",
}

revealSkill:addEffect("active", {
  prompt = "#reveal_skill&",
  interaction = function(self, player)
    local choiceList = {}
    if (player.general == "anjiang" and not player:prohibitReveal()) then
      local general = Fk.generals[player:getMark("__heg_general")]
      for _, sname in ipairs(general:getSkillNameList(true)) do
        local s = Fk.skills[sname]
        if s:hasTag(Skill.Compulsory) and not s:hasTag(Skill.DeputyPlace) and table.contains(player.player_skills, s) then
          table.insert(choiceList, "revealMain:::" .. general.name)
          break
        end
      end
    end
    if (player.deputyGeneral == "anjiang" and not player:prohibitReveal(true)) then
      local general = Fk.generals[player:getMark("__heg_deputy")]
      for _, sname in ipairs(general:getSkillNameList(true)) do
        local s = Fk.skills[sname]
        if s:hasTag(Skill.Compulsory) and not s:hasTag(Skill.MainPlace) and table.contains(player.player_skills, s) then
          table.insert(choiceList, "revealDeputy:::" .. general.name)
          break
        end
      end
    end
    if #choiceList == 0 then return false end
    return UI.ComboBox { choices = choiceList }
  end,
  target_num = 0,
  card_num = 0,
  card_filter = Util.FalseFunc,
  on_use = function(self, room, effect)
    local player = effect.from
    local choice = self.interaction.data
    if not choice then return false
    elseif choice:startsWith("revealMain") then player:revealGeneral(false)
    elseif choice:startsWith("revealDeputy") then player:revealGeneral(true) end
  end,
  can_use = function(self, player)
    if (player.general == "anjiang" and not player:prohibitReveal()) then
      local general = Fk.generals[player:getMark("__heg_general")]
      for _, sname in ipairs(general:getSkillNameList(true)) do
        local s = Fk.skills[sname]
        if s:hasTag(Skill.Compulsory) and not s:hasTag(Skill.DeputyPlace) and table.contains(player.player_skills, s) then
          return true
        end
      end
    end
    if (player.deputyGeneral == "anjiang" and not player:prohibitReveal(true)) then
      local general = Fk.generals[player:getMark("__heg_deputy")]
      for _, sname in ipairs(general:getSkillNameList(true)) do
        local s = Fk.skills[sname]
        if s:hasTag(Skill.Compulsory) and not s:hasTag(Skill.MainPlace) and table.contains(player.player_skills, s) then
          return true
        end
      end
    end
    return false
  end
})

return revealSkill
