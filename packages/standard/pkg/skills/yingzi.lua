local yingzi = fk.CreateSkill {
  name = "yingzi",
}

yingzi:addEffect(fk.DrawNCards, {
  anim_type = "drawcard",
  on_use = function(self, event, target, player, data)
    data.n = data.n + 1
  end,
})

yingzi:addAI(Fk.Ltk.AI.newInvokeStrategy{
  think = Util.TrueFunc
})

return yingzi
