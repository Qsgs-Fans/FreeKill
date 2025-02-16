local skill = fk.CreateSkill {
  name = "#axe_skill",
  attached_equip = "axe",
}

skill:addEffect(fk.CardEffectCancelledOut, {
  prompt = "#spear_skill",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and data.from == player and data.card.trueName == "slash" and not data.to.dead
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local cards = {}
    for _, id in ipairs(player:getCardIds("he")) do
      if not player:prohibitDiscard(id) and
        not (table.contains(player:getEquipments(Card.SubtypeWeapon), id) and Fk:getCardById(id).name == "axe") then
        table.insert(cards, id)
      end
    end
    cards = room:askForDiscard(player, 2, 2, true, self.name, true, tostring(Exppattern{ id = cards }), "#axe-invoke::"..data.to.id, true)
    if #cards > 0 then
      self.cost_data = {cards = cards}
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    player.room:throwCard(self.cost_data.cards, skill.name, player, player)
    return true
  end,
})

return skill
