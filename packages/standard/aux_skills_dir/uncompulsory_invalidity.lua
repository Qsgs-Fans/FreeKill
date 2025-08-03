local uncompulsoryInvalidity = fk.CreateSkill {
  name = "uncompulsory_invalidity",
}

uncompulsoryInvalidity:addEffect("invalidity", {
  global = true,
  invalidity_func = function(self, from, skill)
    return
      not skill:hasTag(Skill.Compulsory) and
      skill:isPlayerSkill(from) and
      from:hasMark(MarkEnum.UncompulsoryInvalidity, MarkEnum.TempMarkSuffix)
  end
})

return uncompulsoryInvalidity
