local skill = fk.CreateSkill {
  name = "spear_skill&",
  attached_equip = "spear",
}

skill:addEffect("viewas", {
  prompt = "#spear_skill&",
  pattern = "slash|0|red,black,nocolor",
  mute_card = false,
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    return #selected < 2 and table.contains(player:getHandlyIds(), to_select)
  end,
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
