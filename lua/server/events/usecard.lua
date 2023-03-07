local playCardEmotionAndSound = function(room, player, card)
  if card.type ~= Card.TypeEquip then
    local anim_path = "./packages/" .. card.package.extensionName .. "/image/anim/" .. card.name
    if not FileIO.exists(anim_path) then
      for _, dir in ipairs(FileIO.ls("./packages/")) do
        anim_path = "./packages/" .. dir .. "/image/anim/" .. card.name
        if FileIO.exists(anim_path) then break end
      end
    end
    if FileIO.exists(anim_path) then room:setEmotion(player, anim_path) end
  end

  local soundName
  if card.type == Card.TypeEquip then
    local subTypeStr
    if card.sub_type == Card.SubtypeDefensiveRide or card.sub_type == Card.SubtypeOffensiveRide then
      subTypeStr = "horse"
    elseif card.sub_type == Card.SubtypeWeapon then
      subTypeStr = "weapon"
    else
      subTypeStr = "armor"
    end

    soundName = "./audio/card/common/" .. subTypeStr
  else
    soundName = "./packages/" .. card.package.extensionName .. "/audio/card/"
      .. (player.gender == General.Male and "male/" or "female/") .. card.name
    if not FileIO.exists(soundName .. ".mp3") then
      for _, dir in ipairs(FileIO.ls("./packages/")) do
        soundName = "./packages/" .. dir .. "/audio/card/"
          .. (player.gender == General.Male and "male/" or "female/") .. card.name
        if FileIO.exists(soundName .. ".mp3") then break end
      end
    end
  end
  room:broadcastPlaySound(soundName)
end

---@param room Room
---@param cardUseEvent CardUseStruct
local sendCardEmotionAndLog = function(room, cardUseEvent)
  local from = cardUseEvent.from
  local _card = cardUseEvent.card

  -- when this function is called, card is already in PlaceTable and no filter skill is applied.
  -- So filter this card manually here to get 'real' use.card
  local card = _card
  if not _card:isVirtual() then
    local temp = { card = _card }
    Fk:filterCard(_card.id, room:getPlayerById(from), temp)
    card = temp.card
  end

  playCardEmotionAndSound(room, room:getPlayerById(from), card)
  room:doAnimate("Indicate", {
    from = from,
    to = cardUseEvent.tos or {},
  })

  local useCardIds = card:isVirtual() and card.subcards or { card.id }
  if cardUseEvent.tos and #cardUseEvent.tos > 0 then
    local to = {}
    for _, t in ipairs(cardUseEvent.tos) do
      table.insert(to, t[1])
    end

    if card:isVirtual() or (card ~= _card) then
      if #useCardIds == 0 then
        room:sendLog{
          type = "#UseV0CardToTargets",
          from = from,
          to = to,
          arg = card:toLogString(),
        }
      else
        room:sendLog{
          type = "#UseVCardToTargets",
          from = from,
          to = to,
          card = useCardIds,
          arg = card:toLogString(),
        }
      end
    else
      room:sendLog{
        type = "#UseCardToTargets",
        from = from,
        to = to,
        card = useCardIds
      }
    end

    for _, t in ipairs(cardUseEvent.tos) do
      if t[2] then
        local temp = {table.unpack(t)}
        table.remove(temp, 1)
        room:sendLog{
          type = "#CardUseCollaborator",
          from = t[1],
          to = temp,
          arg = card.name,
        }
      end
    end
  elseif cardUseEvent.toCard then
    if card:isVirtual() or (card ~= _card) then
      if #useCardIds == 0 then
        room:sendLog{
          type = "#UseV0CardToCard",
          from = from,
          arg = cardUseEvent.toCard.name,
          arg2 = card:toLogString(),
        }
      else
        room:sendLog{
          type = "#UseVCardToCard",
          from = from,
          card = useCardIds,
          arg = cardUseEvent.toCard.name,
          arg2 = card:toLogString(),
        }
      end
    else
      room:sendLog{
        type = "#UseCardToCard",
        from = from,
        card = useCardIds,
        arg = cardUseEvent.toCard.name,
      }
    end
  else
    if card:isVirtual() or (card ~= _card) then
      if #useCardIds == 0 then
        room:sendLog{
          type = "#UseV0Card",
          from = from,
          arg = card:toLogString(),
        }
      else
        room:sendLog{
          type = "#UseVCard",
          from = from,
          card = useCardIds,
          arg = card:toLogString(),
        }
      end
    else
      room:sendLog{
        type = "#UseCard",
        from = from,
        card = useCardIds,
      }
    end
  end
end

---@param self GameEvent
GameEvent.functions[GameEvent.UseCard] = function(self)
  local cardUseEvent = table.unpack(self.data)
  local self = self.room
  local from = cardUseEvent.from
  self:moveCards({
    ids = self:getSubcardsByRule(cardUseEvent.card),
    from = from,
    toArea = Card.Processing,
    moveReason = fk.ReasonUse,
  })

  if cardUseEvent.card.skill then
    cardUseEvent.card.skill:onUse(self, cardUseEvent)
  end

  sendCardEmotionAndLog(self, cardUseEvent)

  if self.logic:trigger(fk.PreCardUse, self:getPlayerById(cardUseEvent.from), cardUseEvent) then
    self.logic:breakEvent()
  end

  if not cardUseEvent.extraUse then
    self:getPlayerById(cardUseEvent.from):addCardUseHistory(cardUseEvent.card.trueName, 1)
  end

  if cardUseEvent.responseToEvent then
    cardUseEvent.responseToEvent.cardsResponded = cardUseEvent.responseToEvent.cardsResponded or {}
    table.insert(cardUseEvent.responseToEvent.cardsResponded, cardUseEvent.card)
  end

  for _, event in ipairs({ fk.AfterCardUseDeclared, fk.AfterCardTargetDeclared, fk.BeforeCardUseEffect, fk.CardUsing }) do
    if not cardUseEvent.toCard and #TargetGroup:getRealTargets(cardUseEvent.tos) == 0 then
      break
    end

    self.logic:trigger(event, self:getPlayerById(cardUseEvent.from), cardUseEvent)
    if event == fk.CardUsing then
      self:doCardUseEffect(cardUseEvent)
    end
  end

  self.logic:trigger(fk.CardUseFinished, self:getPlayerById(cardUseEvent.from), cardUseEvent)
end

GameEvent.cleaners[GameEvent.UseCard] = function(self)
  local cardUseEvent = table.unpack(self.data)
  local self = self.room

  local leftRealCardIds = self:getSubcardsByRule(cardUseEvent.card, { Card.Processing })
  if #leftRealCardIds > 0 then
    self:moveCards({
      ids = leftRealCardIds,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPutIntoDiscardPile,
    })
  end
end

GameEvent.functions[GameEvent.RespondCard] = function(self)
  local cardResponseEvent = table.unpack(self.data)
  local self = self.room
  local from = cardResponseEvent.customFrom or cardResponseEvent.from
  local card = cardResponseEvent.card
  local cardIds = self:getSubcardsByRule(card)

  if card:isVirtual() then
    if #cardIds == 0 then
      self:sendLog{
        type = "#ResponsePlayV0Card",
        from = from,
        arg = card:toLogString(),
      }
    else
      self:sendLog{
        type = "#ResponsePlayVCard",
        from = from,
        card = cardIds,
        arg = card:toLogString(),
      }
    end
  else
    self:sendLog{
      type = "#ResponsePlayCard",
      from = from,
      card = cardIds,
    }
  end
  self:moveCards({
    ids = cardIds,
    from = from,
    toArea = Card.Processing,
    moveReason = fk.ReasonResonpse,
  })

  playCardEmotionAndSound(self, self:getPlayerById(from), card)

  for _, event in ipairs({ fk.PreCardRespond, fk.CardResponding, fk.CardRespondFinished }) do
    self.logic:trigger(event, self:getPlayerById(cardResponseEvent.from), cardResponseEvent)
  end

  local realCardIds = self:getSubcardsByRule(cardResponseEvent.card, { Card.Processing })
  if #realCardIds > 0 and not cardResponseEvent.skipDrop then
    self:moveCards({
      ids = realCardIds,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPutIntoDiscardPile,
    })
  end
end
