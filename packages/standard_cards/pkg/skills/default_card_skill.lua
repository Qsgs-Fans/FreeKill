local skill = fk.CreateSkill{
  name = "default_card_skill",
}

skill:addEffect("active", {
  on_use = function(self, room, use)
    if not use.tos or #use.tos == 0 then
      use.tos = { use.from }
    end
  end
})

return skill
