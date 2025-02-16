local skill = fk.CreateSkill {
  name = "jink_skill",
}

skill:addEffect("active", {
  can_use = Util.FalseFunc,
  on_effect = function(self, room, effect)
    if effect.responseToEvent then
      effect.responseToEvent.isCancellOut = true
    end
  end,
})

return skill
