local longdan = fk.CreateSkill {
  name = "longdan",
}

longdan:addEffect("viewas", {
  pattern = "slash,jink",
  prompt = "#longdan",
  handly_pile = true,
  filter_pattern = function (self, player, card_name)
    local vs_pattern = {
      max_num = 1,
      min_num = 1,
      pattern = "slash,jink",
    }
    if card_name == "slash" then
      vs_pattern.pattern = "jink"
    elseif card_name == "jink" then
      vs_pattern.pattern = "slash"
    end
    return vs_pattern
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return end
    local _c = Fk:getCardById(cards[1])
    local c
    if _c.trueName == "slash" then
      c = Fk:cloneCard("jink")
    elseif _c.name == "jink" then
      c = Fk:cloneCard("slash")
    else
      return nil
    end
    c.skillName = longdan.name
    c:addSubcard(cards[1])
    return c
  end,
})

longdan:addAI(nil, "vs_skill")

return longdan
