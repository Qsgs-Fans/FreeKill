local jizhi = fk.CreateSkill{
  name = "jizhi",
}

jizhi:addEffect(fk.CardUsing, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(jizhi.name) and
      data.card:isCommonTrick() and not data.card:isConverted()
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, jizhi.name)
  end,
})

local AI = Fk.Ltk.AI
jizhi:addAI(AI.reuse("biyue", AI.InvokeStrategy))

return jizhi
