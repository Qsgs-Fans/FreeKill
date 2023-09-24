-- SPDX-License-Identifier: GPL-3.0-or-later

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
  ---[[
  if not _card:isVirtual() then
    local temp = { card = _card }
    Fk:filterCard(_card.id, room:getPlayerById(from), temp)
    card = temp.card
  end
  cardUseEvent.card = card
  --]]

  playCardEmotionAndSound(room, room:getPlayerById(from), card)
  room:doAnimate("Indicate", {
    from = from,
    to = cardUseEvent.tos or Util.DummyTable,
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

  if #useCardIds == 0 then return end
  if cardUseEvent.tos and #cardUseEvent.tos > 0 and #cardUseEvent.tos <= 2 then
    local tos = table.map(cardUseEvent.tos, function(e) return e[1] end)
    room:sendFootnote(useCardIds, {
      type = "##UseCardTo",
      from = from,
      to = tos,
    })
    if card:isVirtual() then
      room:sendCardVirtName(useCardIds, card.name)
    end
  else
    room:sendFootnote(useCardIds, {
      type = "##UseCard",
      from = from,
    })
    if card:isVirtual() then
      room:sendCardVirtName(useCardIds, card.name)
    end
  end
end

GameEvent.functions[GameEvent.UseCard] = function(self)
  local cardUseEvent = table.unpack(self.data)
  local room = self.room
  local logic = room.logic

  if cardUseEvent.card.skill then
    cardUseEvent.card.skill:onUse(room, cardUseEvent)
  end

  if room.logic:trigger(fk.PreCardUse, room:getPlayerById(cardUseEvent.from), cardUseEvent) then
    cardUseEvent.breakEvent = true --增加终止判定参数
    self.data = { cardUseEvent }   --传回数据
    room.logic:breakEvent()
  end

  room:moveCardTo(cardUseEvent.card, Card.Processing, nil, fk.ReasonUse)

  sendCardEmotionAndLog(room, cardUseEvent)

  if not cardUseEvent.extraUse then
    room:getPlayerById(cardUseEvent.from):addCardUseHistory(cardUseEvent.card.trueName, 1)
  end

  if cardUseEvent.responseToEvent then
    cardUseEvent.responseToEvent.cardsResponded = cardUseEvent.responseToEvent.cardsResponded or {}
    table.insertIfNeed(cardUseEvent.responseToEvent.cardsResponded, cardUseEvent.card)
  end

  for _, event in ipairs({ fk.AfterCardUseDeclared, fk.AfterCardTargetDeclared, fk.CardUsing }) do
    if not cardUseEvent.toCard and #TargetGroup:getRealTargets(cardUseEvent.tos) == 0 then
      break
    end

    logic:trigger(event, room:getPlayerById(cardUseEvent.from), cardUseEvent)
    if event == fk.CardUsing then
      room:doCardUseEffect(cardUseEvent)
    end
  end
end

GameEvent.cleaners[GameEvent.UseCard] = function(self)
  local cardUseEvent = table.unpack(self.data)
  local room = self.room

  room.logic:trigger(fk.CardUseFinished, room:getPlayerById(cardUseEvent.from), cardUseEvent)

  local leftRealCardIds = room:getSubcardsByRule(cardUseEvent.card, { Card.Processing })
  if #leftRealCardIds > 0 then
    room:moveCards({
      ids = leftRealCardIds,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonUse,
    })
  end
end

GameEvent.functions[GameEvent.RespondCard] = function(self)
  local cardResponseEvent = table.unpack(self.data)
  local room = self.room
  local logic = room.logic

  if room.logic:trigger(fk.PreCardRespond, room:getPlayerById(cardResponseEvent.from), cardResponseEvent) then
      cardResponseEvent.breakEvent = true
      self.data = { cardResponseEvent }
      room.logic:breakEvent()
  end

  local from = cardResponseEvent.customFrom or cardResponseEvent.from
  local card = cardResponseEvent.card
  local cardIds = room:getSubcardsByRule(card)

  if card:isVirtual() then
    if #cardIds == 0 then
      room:sendLog{
        type = "#ResponsePlayV0Card",
        from = from,
        arg = card:toLogString(),
      }
    else
      room:sendLog{
        type = "#ResponsePlayVCard",
        from = from,
        card = cardIds,
        arg = card:toLogString(),
      }
    end
  else
    room:sendLog{
      type = "#ResponsePlayCard",
      from = from,
      card = cardIds,
    }
  end
  room:moveCardTo(card, Card.Processing, nil, fk.ReasonResonpse)
  if #cardIds > 0 then
    room:sendFootnote(cardIds, {
      type = "##ResponsePlayCard",
      from = from,
    })
    if card:isVirtual() then
      room:sendCardVirtName(cardIds, card.name)
    end
  end

  if not cardResponseEvent.retrial then--不是改判打出就播放配音
    playCardEmotionAndSound(room, room:getPlayerById(from), card)
  end

  logic:trigger(fk.CardResponding, room:getPlayerById(cardResponseEvent.from), cardResponseEvent)
end

GameEvent.cleaners[GameEvent.RespondCard] = function(self)
  local cardResponseEvent = table.unpack(self.data)
  local room = self.room

  room.logic:trigger(fk.CardRespondFinished, room:getPlayerById(cardResponseEvent.from), cardResponseEvent)

  local realCardIds = room:getSubcardsByRule(cardResponseEvent.card, { Card.Processing })
  if #realCardIds > 0 and not cardResponseEvent.skipDrop then
    room:moveCards({
      ids = realCardIds,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonResonpse,
    })
  end
end

GameEvent.functions[GameEvent.CardEffect] = function(self)
  local cardEffectEvent = table.unpack(self.data)
  local room = self.room
  local logic = room.logic

  for _, event in ipairs({ fk.PreCardEffect, fk.BeforeCardEffect, fk.CardEffecting, fk.CardEffectFinished }) do
    local user = cardEffectEvent.from and room:getPlayerById(cardEffectEvent.from) or nil
    if cardEffectEvent.isCancellOut then
      if logic:trigger(fk.CardEffectCancelledOut, user, cardEffectEvent) then
        cardEffectEvent.isCancellOut = false
      else
        logic:breakEvent()
      end
    end

    if
      not cardEffectEvent.toCard and
      (
        not (room:getPlayerById(cardEffectEvent.to):isAlive() and cardEffectEvent.to)
        or #room:deadPlayerFilter(TargetGroup:getRealTargets(cardEffectEvent.tos)) == 0
      )
    then
      logic:breakEvent()
    end

    if table.contains((cardEffectEvent.nullifiedTargets or Util.DummyTable), cardEffectEvent.to) then
      logic:breakEvent()
    end

    if event == fk.PreCardEffect then
      if cardEffectEvent.from and logic:trigger(event, room:getPlayerById(cardEffectEvent.from), cardEffectEvent) then
        logic:breakEvent()
      end
    elseif cardEffectEvent.to and logic:trigger(event, room:getPlayerById(cardEffectEvent.to), cardEffectEvent) then
      logic:breakEvent()
    end

    room:handleCardEffect(event, cardEffectEvent)
  end
end
