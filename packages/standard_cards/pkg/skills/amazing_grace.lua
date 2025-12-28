local skill = fk.CreateSkill {
  name = "amazing_grace_skill",
}

skill:addEffect("cardskill", {
  prompt = "#amazing_grace_skill",
  can_use = Util.CanUseFixedTarget,
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
  about_to_effect = function(self, room, effect)
    if not (effect.extra_data and next(effect.extra_data.AGFilled or {})) then
      return true
    end
  end,
  on_effect = function(self, room, effect)
    local to = effect.to

    local chosen = room:askToAG(to, { id_list = effect.extra_data.AGFilled, cancelable = false, skill_name = self.name })
    room:takeAG(to, chosen, room.players)
    table.insert(effect.extra_data.AGResult, {effect.to.id, chosen})
    room:moveCardTo(chosen, Card.PlayerHand, effect.to, fk.ReasonPrey, self.name, nil, true, effect.to)
    effect.extra_data.AGFilled = table.filter(effect.extra_data.AGFilled, function(id)
      return room:getCardArea(id) == Card.Processing
    end)
  end,
})

skill:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:useCard {
      from = me,
      tos = {},
      card = Fk:cloneCard("amazing_grace"),
    }
  end)
  lu.assertEquals(#me:getCardIds("h"), 1)
  lu.assertEquals(#room.players[2]:getCardIds("h"), 1)
  lu.assertEquals(#room.players[3]:getCardIds("h"), 1)
end)

skill:addAI(Fk.Ltk.AI.newCardSkillStrategy {
  keep_value = -1,
  use_value = 3,
  use_priority = 1.2,
})

return skill
