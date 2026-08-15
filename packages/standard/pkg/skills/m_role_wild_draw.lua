local wildDraw = fk.CreateSkill {
  name = "m_role_wild_draw&",
}
wildDraw:addEffect("active", {
  prompt = "#m_role_wild_draw&",
  anim_type = "drawcard",
  can_use = function(self, player)
    return player:getMark("@!!m_role_wild") > 0
  end,
  card_filter = Util.FalseFunc,
  target_num = 0,
  interaction = function(self, player)
    local choices = { "draw2" }
    if player:isWounded() then table.insert(choices, "recover") end
    return UI.OptionBox { options = choices }
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local choice = self.interaction.data
    if choice == "draw2" then
      player:drawCards(2, wildDraw.name)
    else
      room:recover { who = player, num = 1, skillName = wildDraw.name, recoverBy = player }
    end
    room:removePlayerMark(player, "@!!m_role_wild", 1)
    if player:getMark("@!!m_role_wild") == 0 then
      room:handleAddLoseSkills(player, "-m_role_wild_draw&", nil, false, true)
    end
  end,
})
Fk:loadTranslationTable {
  ["m_role_wild_draw&"] = "野心家",
  ["#m_role_wild_draw&"] = "你可弃一枚“野心家”标记，摸两张牌或回复1点体力",
  [":m_role_wild_draw&"] = "出牌阶段，你可弃一枚“野心家”标记，摸两张牌或回复1点体力。",

  ["@!!m_role_wild"] = "野心家",
  [":@!!m_role_wild"] = "出牌阶段，你可弃一枚“野心家”标记，摸两张牌或回复1点体力。",
}

return wildDraw
