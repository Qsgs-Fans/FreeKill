local jiuyuan = fk.CreateSkill{
  name = "jiuyuan",
  tags = { Skill.Lord, Skill.Compulsory },
}

jiuyuan:addEffect(fk.PreHpRecover, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(jiuyuan.name) and
      data.card and data.card.trueName == "peach" and
      data.recoverBy and data.recoverBy.kingdom == "wu" and data.recoverBy ~= player
  end,
  on_use = function(self, event, target, player, data)
    data:changeRecover(1)
  end,
})

jiuyuan:addAI({
  correct_func = function(self, logic, event, target, player, data)
    if self.skill:triggerable(event, target, player, data) then
      data.num = data.num + 1
    end
  end,
}, nil, nil, true)

return jiuyuan
