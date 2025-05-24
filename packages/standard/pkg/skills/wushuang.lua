local wushuang = fk.CreateSkill {
  name = "wushuang",
  tags = { Skill.Compulsory },
}

---@type TrigSkelSpec<AimFunc>
local wushuang_spec = {
  on_use = function(self, event, target, player, data)
    data.fixedResponseTimes = 2
    if data.card.trueName == "duel" then
      data.fixedAddTimesResponsors = data.fixedAddTimesResponsors or {}
      table.insertIfNeed(data.fixedAddTimesResponsors, (event == fk.TargetSpecified) and data.to or data.from)
    end
  end,
}

wushuang:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(wushuang.name) and
      table.contains({ "slash", "duel" }, data.card.trueName)
  end,
  on_use = wushuang_spec.on_use
})

wushuang:addEffect(fk.TargetConfirmed, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(wushuang.name) and data.card.trueName == "duel"
  end,
  on_use = wushuang_spec.on_use
})

return wushuang
