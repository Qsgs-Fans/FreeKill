fk.ai_card_keep_value["thunder__slash"] = 20
SmartAI:setCardSkillAI("thunder__slash_skill", nil, "slash_skill")

fk.ai_card_keep_value["fire__slash"] = 35
SmartAI:setCardSkillAI("fire__slash_skill", nil, "slash_skill")

SmartAI:setCardSkillAI("iron_chain_skill", {
  on_effect = function(self, logic, effect)
    local target = effect.to
    logic:setPlayerProperty(target, "chained", not target.chained)
  end,
})

SmartAI:setCardSkillAI("fire_attack_skill", {
  on_effect = function(self, logic, effect)
    local from = effect.from
    local to = effect.to
    if to:isKongcheng() then return end
    if from:isKongcheng() then return end
    logic:throwCard(from.player_cards[Player.Hand][1], self.skill.name, from)
    logic:damage({
      from = from,
      to = to,
      card = effect.card,
      damage = 1,
      damageType = fk.FireDamage,
      skillName = self.skill.name
    })
  end,
})

SmartAI:setCardSkillAI("supply_shortage_skill")

--[[
SmartAI:setSkillAI("analeptic_skill", just_use)
--]]
fk.ai_card_keep_value["analeptic"] = 30

fk.ai_card_keep_value["iron_chain"] = 25

fk.ai_card_keep_value["fire_attack"] = 30

fk.ai_card_keep_value["supply_shortage"] = 45

fk.ai_card_keep_value["guding_blade"] = 20
SmartAI:setTriggerSkillAI("#guding_blade_skill", {
  correct_func = function(self, logic, event, target, player, data)
    if self.skill:triggerable(event, target, player, data) then
      data.damage = data.damage + 1
    end
  end,
})

fk.ai_card_keep_value["vine"] = 30
SmartAI:setTriggerSkillAI("#vine_skill", {
  correct_func = function(self, logic, event, target, player, data)
    local skill = self.skill
    if skill:triggerable(event, target, player, data) then
      if event == fk.DamageInflicted then
        data.damage = data.damage + 1
      else
        return true
      end
    end
  end,
})

fk.ai_card_keep_value["hualiu"] = 20

fk.ai_card_keep_value["silver_lion"] = 20

fk.ai_card_keep_value["fan"] = 20
