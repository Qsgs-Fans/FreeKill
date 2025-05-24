local rende = fk.CreateSkill {
  name = "test_rende",
}

rende:addEffect("active", {
  anim_type = "support",
  prompt = "#test_rende-active",
  min_card_num = 1,
  min_target_num = 0,
  card_filter = function(self, player, to_select, selected)
    return table.contains(player:getCardIds("he"), to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    return to_select ~= player
  end,
  on_use = function(self, room, effect)
    local cards = effect.cards
    local player = effect.from
    if #effect.tos == 0 then
      room:moveCardTo(cards, Card.DrawPile, nil, fk.ReasonPut, rende.name, nil, false, player)
    else
      local num_targets = #effect.tos
      local num_cards = #cards
      local cards_per_target = math.floor(num_cards / num_targets)
      local extra_cards = num_cards % num_targets

      local card_groups = {}
      local index = 1
      for i = 1, num_targets do
        local group_size = cards_per_target + (i <= extra_cards and 1 or 0)
        card_groups[i] = {}
        for _ = 1, group_size do
          table.insert(card_groups[i], cards[index])
          index = index + 1
        end
      end
      for i, target in ipairs(effect.tos) do
        room:moveCardTo(card_groups[i], Player.Hand, target, fk.ReasonGive, rende.name, nil, false, player)
      end
    end
  end,
})

Fk:loadTranslationTable{
  ["test_rende"] = "给牌",
  [":test_rende"] = "出牌阶段，你可以交给任意名角色任意张牌（按顺序均分），或将任意张牌置于牌堆顶。",
  ["#test_rende-active"] = "给牌：你可以交给任意名角色任意张牌（按顺序均分），或将任意张牌置于牌堆顶",
}

return rende
