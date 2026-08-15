
local baihu = fk.CreateSkill{
  name = "baihu_emblem&",
  mode_skill = true,
}

Fk:loadTranslationTable{
  ["baihu_emblem&"] = "白虎",
  [":baihu_emblem&"] = "你可以将一张牌当【杀】或【闪】使用或打出。",

  ["#baihu_emblem&"] = "白虎：你可以将一张牌当【杀】或【闪】使用或打出",
}

baihu:addEffect("viewas", {
  pattern = "slash,jink",
  prompt = "#baihu_emblem&",
  interaction = function (self, player)
    local all_names = { "slash", "jink" }
    local names = player:getViewAsCardNames(baihu.name, all_names)
    if #names == 0 then return end
    return UI.CardNameBox { choices = names, all_choices = all_names }
  end,
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".",
  },
  view_as = function(self, player, cards)
    if #cards ~= 1 or not self.interaction.data then return end
    local card = Fk:cloneCard(self.interaction.data)
    card:addSubcard(cards[1])
    card.skillName = baihu.name
    return card
  end,
  before_use = function (self, player, use)
    player.room:handleAddLoseSkills(player, "-baihu_emblem&", nil, false, true)
  end,
})

baihu:addEffect(fk.TurnEnd, {
  late_refresh = true,
  can_refresh = function (self, event, target, player, data)
    return player:hasSkill(baihu.name, true) and
      not table.find(player.room.alive_players, function (p)
        return p.role:endsWith("rebel")
      end)
  end,
  on_refresh = function (self, event, target, player, data)
    player.room:handleAddLoseSkills(player, "-"..baihu.name)
  end,
})

return baihu
