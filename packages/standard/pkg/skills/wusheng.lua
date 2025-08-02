local wusheng = fk.CreateSkill {
  name = "wusheng",
}

wusheng:addEffect("viewas", {
  anim_type = "offensive",
  pattern = "slash|.|heart,diamond",
  prompt = "#wusheng",
  -- mute_card = true,
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".|.|heart,diamond",
  },
  view_as = function(self, player, cards)
    if #cards ~= 1 then return end
    local c = Fk:cloneCard("slash")
    c.skillName = wusheng.name
    c:addSubcard(cards[1])
    return c
  end,
})

wusheng:addAI(nil, "vs_skill")

return wusheng
