local hujia = fk.CreateSkill {
  name = "hujia",
  tags = { Skill.Lord },
}

local hujia_spec = {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(hujia.name) and
      Exppattern:Parse(data.pattern):matchExp("jink") and
      (data.extraData == nil or data.extraData.hujia_ask == nil) and
      not table.every(player.room.alive_players, function(p)
        return p == player or p.kingdom ~= "wei"
      end)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room:getOtherPlayers(player)) do
      if p:isAlive() and p.kingdom == "wei" then
        local params = { ---@type AskToUseCardParams
          skill_name = "jink",
          pattern = "jink",
          prompt = "#hujia-ask:" .. player.id,
          cancelable = true,
          extra_data = {hujia_ask = true}
        }
        local respond = room:askToResponse(p, params)
        if respond then
          respond.skipDrop = true
          room:responseCard(respond)

          local new_card = Fk:cloneCard('jink')
          new_card.skillName = hujia.name
          new_card:addSubcards(room:getSubcardsByRule(respond.card, { Card.Processing }))
          local result = {
            from = player,
            card = new_card,
          }
          if event == fk.AskForCardUse then
            result.tos = {}
          end
          data.result = result
          return true
        end
      end
    end
  end,
}

hujia:addEffect(fk.AskForCardUse, hujia_spec)
hujia:addEffect(fk.AskForCardResponse, hujia_spec)

return hujia
