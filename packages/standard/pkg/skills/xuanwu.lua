
local xuanwu = fk.CreateSkill {
  name = "xuanwu_emblem&",
  mode_skill = true,
}

Fk:loadTranslationTable{
  ["xuanwu_emblem&"] = "玄武",
  [":xuanwu_emblem&"] = "你可以将一张牌当【桃】使用。",

  ["#xuanwu_emblem&"] = "玄武：你可以将一张牌当【桃】使用",
}

xuanwu:addEffect("viewas", {
  anim_type = "support",
  pattern = "peach",
  prompt = "#xuanwu_emblem&",
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".",
  },
  view_as = function(self, player, cards)
    if #cards ~= 1 then return end
    local c = Fk:cloneCard("peach")
    c.skillName = xuanwu.name
    c:addSubcard(cards[1])
    return c
  end,
  before_use = function (self, player, use)
    player.room:handleAddLoseSkills(player, "-xuanwu_emblem&", nil, false, true)
  end,
  enabled_at_response = function (self, player, response)
    return not response
  end,
})

xuanwu:addEffect(fk.TurnEnd, {
  late_refresh = true,
  can_refresh = function (self, event, target, player, data)
    return player:hasSkill(xuanwu.name, true) and
      not table.find(player.room.alive_players, function (p)
        return p.role:endsWith("rebel")
      end)
  end,
  on_refresh = function (self, event, target, player, data)
    player.room:handleAddLoseSkills(player, "-"..xuanwu.name)
  end,
})

return xuanwu
