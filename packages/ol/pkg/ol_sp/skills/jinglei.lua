local jinglei = fk.CreateSkill{
  name = "jinglei",
}

Fk:loadTranslationTable{
  ["jinglei"] = "惊雷",
  [":jinglei"] = "每回合限一次，一名角色使用【酒】结算后，若没有处于濒死状态的角色，你可以受到1点无来源的雷电伤害，令一名拥有〖煮酒〗的角色"..
  "将手牌调整至体力上限（至多摸至五张），若不为你，其将以此法弃置的牌交给你。",

  ["#jinglei-choose"] = "惊雷：你可以受到1点雷电伤害，令一名有“煮酒”的角色将手牌调整至体力上限（至多摸至五）",

  ["$jinglei1"] = "备得仕于朝，天下英雄实有未知。",
  ["$jinglei2"] = "闻惊雷而颤，备肉眼安识英雄？",
}

jinglei:addEffect(fk.CardUseFinished, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(jinglei.name) and data.card.trueName == "analeptic" and
      player:usedSkillTimes(jinglei.name, Player.HistoryTurn) == 0 and
      table.find(player.room.alive_players, function(p)
        return p:hasSkill("zhujiu", true)
      end) and
      table.every(player.room.alive_players, function(p)
        return not p.dying
      end)
  end,
  on_cost = function(self, event, target, player, data)
    -- 仅确认是否发动技能，不选择目标
    return player.room:askForSkillInvoke(player, jinglei.name)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    
    -- 先受到1点雷电伤害
    room:damage{
      to = player,
      damage = 1,
      damageType = fk.ThunderDamage,
      skillName = jinglei.name,
    }
    
    -- 伤害后检查是否存活
    if player.dead then return end
    
    -- 伤害后选择目标
    local targets = table.filter(room.alive_players, function(p)
      return p:hasSkill("zhujiu", true)
    end)
    
    local to = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = targets,
      skill_name = jinglei.name,
      prompt = "#jinglei-choose",
      cancelable = true,
    })
    
    if #to == 0 then return end
    to = to[1]
    if to.dead then return end
    
    -- 调整手牌逻辑（保持不变）
    local target_num = math.min(to.maxHp, 5)
    local cur_num = to:getHandcardNum()
    
    if cur_num > target_num then
      local discard_num = cur_num - target_num
      local cards = room:askToDiscard(to, {
        min_num = discard_num,
        max_num = discard_num,
        include_equip = false,
        skill_name = jinglei.name,
        cancelable = false,
      })
      
      if to ~= player and not player.dead and #cards > 0 then
        cards = table.filter(cards, function(id)
          return table.contains(room.discard_pile, id)
        end)
        if #cards > 0 then
          room:moveCardTo(cards, Card.PlayerHand, player, fk.ReasonJustMove, jinglei.name, nil, true, player)
        end
      end
    elseif cur_num < target_num then
      to:drawCards(target_num - cur_num, jinglei.name)
    end
  end,
})

return jinglei