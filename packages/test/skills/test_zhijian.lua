local zhijian = fk.CreateSkill {
  name = "test_zhijian",
}

Fk:loadTranslationTable{
  ["test_zhijian"] = "上装",
  [":test_zhijian"] = "出牌阶段，你可以将任意张装备牌置于一名角色的装备区里（替换原装备）（不选牌则从牌堆中随机一张装备牌，不选角色则装给自己）。",

  ["#test_zhijian"] = "上装：选择任意张装备牌置入一名角色的装备区（替换原装备）（不选牌则从牌堆中随机一张装备牌，不选角色则装给自己）",
}

zhijian:addEffect("active", {
  anim_type = "support",
  min_card_num = 0,
  min_target_num = 0,
  max_target_num = 1,
  prompt = "#test_zhijian",
  card_filter = function(self, player, to_select, selected)
    return Fk:getCardById(to_select).type == Card.TypeEquip
  end,
  target_filter = function(self, player, to_select, selected, selected_cards)
    return #selected == 0 and (#selected_cards == 0 or table.find(selected_cards, function(c)
      return to_select:canMoveCardIntoEquip(c) end))
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = #effect.tos > 0 and effect.tos[1] or player
    local cards = #effect.cards > 0 and effect.cards or room:getCardsFromPileByRule( ".|.|.|.|.|equip", 1,"allPiles")
    room:moveCardIntoEquip(target, cards, zhijian.name, true, player)
  end,
})

return zhijian
