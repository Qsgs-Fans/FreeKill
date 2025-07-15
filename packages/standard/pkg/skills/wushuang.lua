local wushuang = fk.CreateSkill {
  name = "wushuang",
  tags = { Skill.Compulsory },
}

---@type TrigSkelSpec<AimFunc>
local wushuang_spec = {
  on_use = function(self, event, target, player, data)
    local to = (event == fk.TargetConfirmed and data.card.trueName == "duel") and data.from or data.to
    data:setResponseTimes(2, to)
  end,
}

wushuang:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(wushuang.name) and
      table.contains({ "slash", "duel" }, data.card.trueName)
  end,
  on_use = wushuang_spec.on_use
})

wushuang:addEffect(fk.TargetConfirmed, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(wushuang.name) and data.card.trueName == "duel"
  end,
  on_use = wushuang_spec.on_use
})

return wushuang
