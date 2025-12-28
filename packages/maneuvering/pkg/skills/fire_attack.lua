local skill = fk.CreateSkill {
  name = "fire_attack_skill",
}

skill:addEffect("cardskill", {
  prompt = "#fire_attack_skill",
  target_num = 1,
  mod_target_filter = function(self, _, to_select, _, _, _)
    return not to_select:isKongcheng()
  end,
  target_filter = Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    local from = effect.from
    local to = effect.to
    if to:isKongcheng() then return end

    local params = { ---@type AskToCardsParams
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = skill.name,
      cancelable = false,
      pattern = ".|.|.|hand",
      prompt = "#fire_attack-show:" .. from.id
    }
    local showCard = room:askToCards(to, params)[1]
    to:showCards(showCard)

    showCard = Fk:getCardById(showCard)
    params = { ---@type AskToDiscardParams
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = skill.name,
      cancelable = true,
      pattern = ".|.|" .. showCard:getSuitString(),
      prompt = "#fire_attack-discard:" .. to.id .. "::" .. showCard:getSuitString()
    }

    --火攻特化的特殊效果
    if effect.extra_data and effect.extra_data.extra_effect then
      local extra_effects = effect.extra_data.extra_effect or {}
      for k, func in pairs(extra_effects) do
        if type(func) == "function" then
          params = func(room, effect, showCard, params)
        end
      end
      if not params.skill_name then
        params.skill_name = skill.name
      end
    end

    local cards = room:askToDiscard(from, params)
    if #cards > 0 and not to.dead then
      room:damage({
        from = from,
        to = to,
        card = effect.card,
        damage = 1,
        damageType = fk.FireDamage,
        skillName = skill.name,
      })
    end
  end,
})

skill:addAI(Fk.Ltk.AI.newCardSkillStrategy {
  keep_value = 3.3,
  use_value = 4.8,
  use_priority = 4.5,

  on_effect = function(self, logic, effect)
    logic:damage({
      from = effect.from,
      to = effect.to,
      card = effect.card,
      damage = 1,
      damageType = fk.FireDamage,
      skillName = skill.name
    })
  end,
})

return skill
