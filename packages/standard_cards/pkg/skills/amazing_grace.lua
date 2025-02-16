local skill = fk.CreateSkill {
  name = "amazing_grace_skill",
}

skill:addEffect("active", {
  prompt = "#amazing_grace_skill",
  can_use = Util.GlobalCanUse,
  on_use = function (self, room, cardUseEvent)
    return Util.AoeCardOnUse(self, cardUseEvent.from, cardUseEvent, true)
  end,
  mod_target_filter = Util.TrueFunc,
  on_action = function(self, room, use, finished)
    use.extra_data = use.extra_data or {}
    if not finished then
      local toDisplay = {}
      if use.extra_data.orig_cards then
        toDisplay = use.extra_data.orig_cards
      else
        toDisplay = room:getNCards(#use.tos)
      end
      room:moveCards({
        ids = toDisplay,
        from = room:getCardOwner(toDisplay[1]),
        toArea = Card.Processing,
        moveReason = fk.ReasonPut,
      })

      for _, p in ipairs(room.players) do
        room:fillAG(p, toDisplay)
      end

      use.extra_data.AGFilled = toDisplay
      use.extra_data.AGResult = {}
    else
      if use.extra_data and use.extra_data.AGFilled then
        for _, p in ipairs(room.players) do
          room:closeAG(p)
        end

        local toDiscard = table.filter(use.extra_data.AGFilled, function(id)
          return room:getCardArea(id) == Card.Processing
        end)

        if #toDiscard > 0 then
          room:moveCards({
            ids = toDiscard,
            toArea = Card.DiscardPile,
            moveReason = fk.ReasonPutIntoDiscardPile,
          })
        end
      end

      use.extra_data.AGFilled = nil
    end
  end,
  on_effect = function(self, room, effect)
    local to = effect.to
    if not (effect.extra_data and effect.extra_data.AGFilled) then
      return
    end

    local chosen = room:askForAG(to, effect.extra_data.AGFilled, false, self.name)
    room:takeAG(to, chosen, room.players)
    table.insert(effect.extra_data.AGResult, {effect.to.id, chosen})
    room:moveCardTo(chosen, Card.PlayerHand, effect.to, fk.ReasonPrey, self.name, nil, true, effect.to.id)
    table.removeOne(effect.extra_data.AGFilled, chosen)
  end,
})

skill:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:useCard {
      from = me,
      card = Fk:cloneCard("amazing_grace"),
    }
  end)
  lu.assertEquals(#me:getCardIds("h"), 1)
  lu.assertEquals(#room.players[2]:getCardIds("h"), 1)
  lu.assertEquals(#room.players[3]:getCardIds("h"), 1)
end)

return skill
