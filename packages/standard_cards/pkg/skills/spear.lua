local skill = fk.CreateSkill {
  name = "spear_skill&",
  attached_equip = "spear",
}

skill:addEffect("viewas", {
  prompt = "#spear_skill&",
  pattern = "slash",
  mute_card = false,
  handly_pile = true,
  filter_pattern = {
    min_num = 2,
    max_num = 2,
    pattern = ".|.|.|^equip",
  },
  view_as = function(self, player, cards)
    if #cards ~= 2 then return nil end
    local c = Fk:cloneCard("slash")
    c.skillName = "spear"
    c:addSubcards(cards)
    return c
  end,
})

skill:addAI(nil, "vs_skill", "spear_skill")

return skill
