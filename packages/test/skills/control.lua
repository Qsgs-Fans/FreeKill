local control = fk.CreateSkill{
  name = "control",
}

Fk:loadTranslationTable{
  ["control"] = "控制",
  [":control"] = "出牌阶段，你可以控制/解除控制若干名其他角色。",
  ["$control"] = "战将临阵，斩关刈城！",
}

control:addEffect("active", {
  anim_type = "control",
  can_use = Util.TrueFunc,
  card_filter = Util.FalseFunc,
  card_num = 0,
  target_filter = function(self, player, to_select)
    return to_select ~= player
  end,
  min_target_num = 1,
  on_use = function(self, room, effect)
    local from = effect.from
    for _, to in ipairs(effect.tos) do
      if to:getMark("mouxushengcontrolled") == 0 then
        room:addPlayerMark(to, "mouxushengcontrolled")
        from:control(to)
      else
        room:setPlayerMark(to, "mouxushengcontrolled", 0)
        to:control(to)
      end
    end
  end,
})

return control
