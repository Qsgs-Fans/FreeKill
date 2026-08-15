
local zhuque = fk.CreateSkill{
  name = "zhuque_emblem&",
  mode_skill = true,
}

Fk:loadTranslationTable{
  ["zhuque_emblem&"] = "朱雀",
  [":zhuque_emblem&"] = "出牌阶段，你可以弃置一张非基本牌，对一名角色造成1点伤害。以此法杀死反贼不执行奖惩。",

  ["#zhuque_emblem&"] = "朱雀：弃置一张非基本牌，对一名角色造成1点伤害",
}

zhuque:addEffect("active", {
  anim_type = "offensive",
  prompt = "#zhuque_emblem&",
  card_num = 1,
  target_num = 1,
  can_use = Util.TrueFunc,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and Fk:getCardById(to_select).type ~= Card.TypeBasic and not player:prohibitDiscard(to_select)
  end,
  target_filter = function(self, player, to_select, selected, selected_cards)
    return #selected == 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos[1]
    room:handleAddLoseSkills(player, "-zhuque_emblem&", nil, false, true)
    room:throwCard(effect.cards, zhuque.name, player, player)
    if not target.dead then
      room:damage{
        from = player,
        to = target,
        damage = 1,
        skillName = zhuque.name,
      }
    end
  end,
})

zhuque:addEffect(fk.BuryVictim, {
  can_refresh = function(self, event, target, player, data)
    return data.killer == player and
      data.damage and data.damage.skillName == zhuque.name and
      target.role:endsWith("rebel")
  end,
  on_refresh = function(self, event, target, player, data)
    data.extra_data = data.extra_data or {}
    data.extra_data.skip_reward_punish = true
  end,
})

zhuque:addEffect(fk.TurnEnd, {
  late_refresh = true,
  can_refresh = function (self, event, target, player, data)
    return player:hasSkill(zhuque.name, true) and
      not table.find(player.room.alive_players, function (p)
        return p.role:endsWith("rebel")
      end)
  end,
  on_refresh = function (self, event, target, player, data)
    player.room:handleAddLoseSkills(player, "-"..zhuque.name)
  end,
})

return zhuque
