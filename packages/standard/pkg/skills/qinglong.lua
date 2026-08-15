
local qinglong = fk.CreateSkill {
  name = "qinglong_emblem&",
  mode_skill = true,
}

Fk:loadTranslationTable{
  ["qinglong_emblem&"] = "青龙",
  [":qinglong_emblem&"] = "你可以将两张牌当【无懈可击】使用。",

  ["#qinglong_emblem&"] = "青龙：你可以将两张牌当【无懈可击】使用。",
}

qinglong:addEffect("viewas", {
  anim_type = "control",
  pattern = "nullification",
  prompt = "#qinglong_emblem&",
  handly_pile = true,
  filter_pattern = {
    min_num = 2,
    max_num = 2,
    pattern = ".",
  },
  view_as = function(self, player, cards)
    if #cards ~= 2 then return end
    local c = Fk:cloneCard("nullification")
    c.skillName = qinglong.name
    c:addSubcards(cards)
    return c
  end,
  before_use = function (self, player, use)
    player.room:handleAddLoseSkills(player, "-qinglong_emblem&", nil, false, true)
  end,
  enabled_at_response = function (self, player, response)
    return not response and #player:getCardIds("he") + #player:getHandlyIds(false) > 1
  end,
  enabled_at_nullification = function (self, player, data)
    return #player:getCardIds("he") + #player:getHandlyIds(false) > 1
  end,
})

qinglong:addEffect(fk.TurnEnd, {
  late_refresh = true,
  can_refresh = function (self, event, target, player, data)
    return player:hasSkill(qinglong.name, true) and
      not table.find(player.room.alive_players, function (p)
        return p.role:endsWith("rebel")
      end)
  end,
  on_refresh = function (self, event, target, player, data)
    player.room:handleAddLoseSkills(player, "-"..qinglong.name)
  end,
})

return qinglong
