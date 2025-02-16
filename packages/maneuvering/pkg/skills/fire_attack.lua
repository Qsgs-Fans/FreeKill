local skill = fk.CreateSkill {
  name = "fire_attack_skill",
}

skill:addEffect("active", {
  prompt = "#fire_attack_skill",
  can_use = Util.CanUse,
  target_num = 1,
  mod_target_filter = function(self, _, to_select, _, _, _)
    return not to_select:isKongcheng()
  end,
  target_filter = Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    local from = effect.from
    local to = effect.to
    if to:isKongcheng() then return end

    local showCard = room:askForCard(to, 1, 1, false, self.name, false, ".|.|.|hand", "#fire_attack-show:" .. from.id)[1]
    to:showCards(showCard)

    showCard = Fk:getCardById(showCard)
    local cards = room:askForDiscard(from, 1, 1, false, self.name, true,
      ".|.|" .. showCard:getSuitString(), "#fire_attack-discard:" .. to.id .. "::" .. showCard:getSuitString())
    if #cards > 0 and not to.dead then
      room:damage({
        from = from,
        to = to,
        card = effect.card,
        damage = 1,
        damageType = fk.FireDamage,
        skillName = self.name,
      })
    end
  end,
})

return skill
