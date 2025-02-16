local skill = fk.CreateSkill {
  name = "spear_skill",
  attached_equip = "spear",
}

skill:addEffect("viewas", {
  prompt = "#spear_skill",
  pattern = "slash",
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    if #selected == 2 then return end
    return table.contains(player:getHandlyIds(true), to_select)
  end,
  view_as = function(self, player, cards)
    if #cards ~= 2 then return nil end
    local c = Fk:cloneCard("slash")
    c.skillName = "spear"
    c:addSubcards(cards)
    return c
  end,
})

return skill
