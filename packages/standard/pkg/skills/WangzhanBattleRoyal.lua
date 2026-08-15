
local rule = fk.CreateSkill {
  name = "#WangzhanBattleRoyal",
  mode_skill = true,
}

Fk:loadTranslationTable{
  ["#WangzhanBattleRoyal"] = "鏖战",
  ["#WangzhanBattleRoyal-ask"] = "由于鏖战效果，请将两张牌置入弃牌堆，否则失去1点体力",
}

rule:addEffect(fk.TurnEnd, {
  priority = 0,
  can_trigger = function (self, event, target, player, data)
    return target == player and player.room:getBanner("@[:]WangzhanBattleRoyal")
  end,
  on_trigger = function (self, event, target, player, data)
    local room = player.room
    if player:hasSkill("wzzz__weizhong") then
      room:setPlayerMark(player, "WangzhanBattleRoyal-tmp", 1)
      room:loseHp(player, 1, "game_rule")
    elseif player:hasSkill("wzzz__zhuiting") then
      room:setPlayerMark(player, "WangzhanBattleRoyal-tmp", 1)
      local cards = room:askToCards(player, {
        min_num = 2,
        max_num = 2,
        include_equip = true,
        skill_name = rule.name,
        prompt = "#WangzhanBattleRoyal-ask",
        cancelable = false,
      })
      if #cards > 0 then
        room:moveCardTo(cards, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile, "game_rule", nil, true, player)
      end
    else
      room:setPlayerMark(player, "WangzhanBattleRoyal-tmp", 1)
      local cards = room:askToCards(player, {
        min_num = 2,
        max_num = 2,
        include_equip = true,
        skill_name = rule.name,
        prompt = "#WangzhanBattleRoyal-ask",
        cancelable = true,
      })
      if #cards > 0 then
        room:moveCardTo(cards, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile, "game_rule", nil, true, player)
      else
        room:loseHp(player, 1, "game_rule")
      end
    end
    room:setPlayerMark(player, "WangzhanBattleRoyal-tmp", 0)
  end,
})

rule:addEffect("invalidity", {
  invalidity_func = function (self, from, skill)
    return from:getMark("WangzhanBattleRoyal-tmp") > 0 and skill:isPlayerSkill(from)
  end,
})

return rule
