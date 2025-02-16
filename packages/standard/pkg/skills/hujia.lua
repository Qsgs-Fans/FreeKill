local hujia = fk.CreateSkill {
  name = "hujia$",
}

local hujia_spec = {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(hujia.name) and
      (data.cardName == "jink" or (data.pattern and Exppattern:Parse(data.pattern):matchExp("jink|0|nosuit|none"))) and
      (data.extraData == nil or data.extraData.hujia_ask == nil) and
      not table.every(player.room.alive_players, function(p)
        return p == player or p.kingdom ~= "wei"
      end)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room:getOtherPlayers(player)) do
      if p:isAlive() and p.kingdom == "wei" then
        local cardResponded = room:askForResponse(p, "jink", "jink", "#hujia-ask:" .. player.id, true, {hujia_ask = true})
        if cardResponded then
          room:responseCard({
            from = p.id,
            card = cardResponded,
            skipDrop = true,
          })

          if event == fk.AskForCardUse then
            data.result = {
              from = player.id,
              card = Fk:cloneCard('jink'),
            }
            data.result.card:addSubcards(room:getSubcardsByRule(cardResponded, { Card.Processing }))
            data.result.card.skillName = hujia.name

            if data.eventData then
              data.result.toCard = data.eventData.toCard
              data.result.responseToEvent = data.eventData.responseToEvent
            end
          else
            data.result = Fk:cloneCard('jink')
            data.result:addSubcards(room:getSubcardsByRule(cardResponded, { Card.Processing }))
            data.result.skillName = hujia.name
          end
          return true
        end
      end
    end
  end,
}

hujia:addEffect(fk.AskForCardUse, hujia_spec)
hujia:addEffect(fk.AskForCardResponse, hujia_spec)

return hujia
