local fankui = fk.CreateSkill({
  name = "fankui",
})

fankui:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(fankui.name)) then return end
    if data.from and not data.from.dead then
      if data.from == player then
        return #player:getCardIds("e") > 0
      else
        return not data.from:isNude()
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local flag = data.from == player and "e" or "he"
    local card = room:askToChooseCard(player, {
      target = data.from,
      flag = flag,
      skill_name = fankui.name,
    })
    room:obtainCard(player, card, false, fk.ReasonPrey, player, fankui.name)
  end
})

fankui:addAI(Fk.Ltk.AI.newInvokeStrategy{
  think = function(self, ai)
    local data = ai.room.logic:getCurrentEvent().data
    local player = ai.player
    local ret, benefit = player.ai:askToChooseCards({
      cards = data.from:getCardIds("he"),
      skill_name = fankui.name,
      data = {
        toArea = Card.PlayerHand,
        target = player,
        reason = fk.ReasonPrey,
        proposer = player,
      },
    })
    return ai:getBenefitOfEvents(function(logic)
      logic:obtainCard(player, ret, false, fk.ReasonPrey, player, fankui.name)
    end) > 0
  end,
})

return fankui
