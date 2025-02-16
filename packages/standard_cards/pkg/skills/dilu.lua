local skill = fk.CreateSkill {
  name = "#dilu_skill",
  attached_equip = "dilu",
  frequency = Skill.Compulsory,
}

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    if to:hasSkill(skill.name) then
      return 1
    end
  end,
})

return skill
