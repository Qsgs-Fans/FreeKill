local bahu = fk.CreateSkill {
  name = "m_bahu",
  tags = { Skill.Compulsory },
  mode_skill = true,
}

Fk:loadTranslationTable{
  ["m_bahu"] = "跋扈",
  [":m_bahu"] = "锁定技，准备阶段，你摸一张牌；出牌阶段，你可以多使用一张【杀】。",
}

bahu:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(bahu.name) and player.phase == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, bahu.name)
  end,
})

bahu:addEffect("targetmod", {
  residue_func = function(self, player, skill, scope, card)
    if player:hasSkill(bahu.name) and card and card.trueName == "slash" and scope == Player.HistoryPhase then
      return 1
    end
  end,
})

return bahu
