local skill = fk.CreateSkill {
  name = "fire__slash_skill",
}

local slash_skill = Fk.skills["slash_skill"] --[[ @as ActiveSkill ]]

skill:addEffect("active", {
  prompt = function(self, player, selected_cards)
    local card = Fk:cloneCard("fire__slash")
    card:addSubcards(selected_cards)
    local max_num = self:getMaxTargetNum(Self, card)
    if max_num > 1 then
      local num = #table.filter(Fk:currentRoom().alive_players, function (p)
        return p ~= player and not player:isProhibited(p, card)
      end)
      max_num = math.min(num, max_num)
    end
    return max_num > 1 and "#fire__slash_skill_multi:::" .. max_num or "#fire__slash_skill"
  end,
  max_phase_use_time = 1,
  target_num = 1,
  can_use = slash_skill.canUse,
  mod_target_filter = slash_skill.modTargetFilter,
  target_filter = slash_skill.targetFilter,
  on_effect = function(self, room, effect)
    room:damage({
      from = effect.from,
      to = effect.to,
      card = effect.card,
      damage = 1,
      damageType = fk.FireDamage,
      skillName = skill.name,
    })
  end,
})

return skill
