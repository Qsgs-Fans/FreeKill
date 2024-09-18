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
      local orig = Fk.all_card_types[card.name]
      soundName = "./packages/" .. orig.package.extensionName .. "/audio/card/"
      .. (player.gender == General.Male and "male/" or "female/") .. orig.name
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
    Fk:filterCard(_card.id, room:getCardOwner(_card), temp)
    card = temp.card
  end
  cardUseEvent.card = card
  --]]

  playCardEmotionAndSound(room, room:getPlayerById(from), card)

  if not cardUseEvent.noIndicate then
    room:doAnimate("Indicate", {
      from = from,
      to = cardUseEvent.tos or Util.DummyTable,
    })
  end

  local useCardIds = card:isVirtual() and card.subcards or { card.id }
  if cardUseEvent.tos and #cardUseEvent.tos > 0 and not cardUseEvent.noIndicate then
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

  return _card
end

---@class GameEvent.UseCard : GameEvent
local UseCard = GameEvent:subclass("GameEvent.UseCard")
function UseCard:main()
  local cardUseEvent = table.unpack(self.data)
  local room = self.room
  local logic = room.logic

  if type(cardUseEvent.attachedSkillAndUser) == "table" then
    local attachedSkillAndUser = table.simpleClone(cardUseEvent.attachedSkillAndUser)
    self:addExitFunc(function()
      if
        type(attachedSkillAndUser) == "table" and
        Fk.skills[attachedSkillAndUser.skillName] and
        Fk.skills[attachedSkillAndUser.skillName].afterUse
      then
        Fk.skills[attachedSkillAndUser.skillName]:afterUse(room:getPlayerById(attachedSkillAndUser.user), cardUseEvent)
      end
    end)
    cardUseEvent.attachedSkillAndUser = nil
  end

  if cardUseEvent.card.skill then
    cardUseEvent.card.skill:onUse(room, cardUseEvent)
  end

  if cardUseEvent.card.type == Card.TypeEquip then
    local targets = TargetGroup:getRealTargets(cardUseEvent.tos)
    if #targets == 1 then
      local target = room:getPlayerById(targets[1])
      local subType = cardUseEvent.card.sub_type
      local equipsExist = target:getEquipments(subType)

      if #equipsExist > 0 and not target:hasEmptyEquipSlot(subType) then
        local choices = table.map(
          equipsExist,
          function(id, index)
            return "#EquipmentChoice:" .. index .. "::" .. Fk:translate(Fk:getCardById(id).name) end
        )
        if target:hasEmptyEquipSlot(subType) then
          table.insert(choices, target:getAvailableEquipSlots(subType)[1])
        end
        cardUseEvent.toPutSlot = room:askForChoice(target, choices, "replace_equip", "#GameRuleReplaceEquipment")
      end
    end
  end

  if logic:trigger(fk.PreCardUse, room:getPlayerById(cardUseEvent.from), cardUseEvent) then
    logic:breakEvent()
  end

  local _card = sendCardEmotionAndLog(room, cardUseEvent)

  room:moveCardTo(cardUseEvent.card, Card.Processing, nil, fk.ReasonUse)

  local card = cardUseEvent.card
  local useCardIds = card:isVirtual() and card.subcards or { card.id }
  if #useCardIds > 0 then
    if cardUseEvent.tos and #cardUseEvent.tos > 0 and #cardUseEvent.tos <= 2 and not cardUseEvent.noIndicate then
      local tos = table.map(cardUseEvent.tos, function(e) return e[1] end)
      room:sendFootnote(useCardIds, {
        type = "##UseCardTo",
        from = cardUseEvent.from,
        to = tos,
      })
      if card:isVirtual() or card ~= _card then
        room:sendCardVirtName(useCardIds, card.name)
      end
    else
      room:sendFootnote(useCardIds, {
        type = "##UseCard",
        from = cardUseEvent.from,
      })
      if card:isVirtual() or card ~= _card then
        room:sendCardVirtName(useCardIds, card.name)
      end
    end
  end

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

function UseCard:clear()
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

---@class GameEvent.RespondCard : GameEvent
local RespondCard = GameEvent:subclass("GameEvent.RespondCard")
function RespondCard:main()
  local cardResponseEvent = table.unpack(self.data)
  local room = self.room
  local logic = room.logic

  if logic:trigger(fk.PreCardRespond, room:getPlayerById(cardResponseEvent.from), cardResponseEvent) then
    logic:breakEvent()
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

  playCardEmotionAndSound(room, room:getPlayerById(from), card)

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

  logic:trigger(fk.CardResponding, room:getPlayerById(cardResponseEvent.from), cardResponseEvent)
end

function RespondCard:clear()
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

---@class GameEvent.CardEffect : GameEvent
local CardEffect = GameEvent:subclass("GameEvent.CardEffect")
function CardEffect:main()
  local cardEffectEvent = table.unpack(self.data)
  local room = self.room
  local logic = room.logic

  for _, event in ipairs({ fk.PreCardEffect, fk.BeforeCardEffect, fk.CardEffecting, fk.CardEffectFinished }) do
    if cardEffectEvent.isCancellOut then
      if logic:trigger(fk.CardEffectCancelledOut, room:getPlayerById(cardEffectEvent.from), cardEffectEvent) then
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
      if logic:trigger(event, room:getPlayerById(cardEffectEvent.from), cardEffectEvent) then
        if cardEffectEvent.to then
          cardEffectEvent.nullifiedTargets = cardEffectEvent.nullifiedTargets or {}
          table.insert(cardEffectEvent.nullifiedTargets, cardEffectEvent.to)
        end
        logic:breakEvent()
      end
    elseif logic:trigger(event, room:getPlayerById(cardEffectEvent.to), cardEffectEvent) then
      if cardEffectEvent.to then
        cardEffectEvent.nullifiedTargets = cardEffectEvent.nullifiedTargets or {}
        table.insert(cardEffectEvent.nullifiedTargets, cardEffectEvent.to)
      end
      logic:breakEvent()
    end

    room:handleCardEffect(event, cardEffectEvent)
  end
end

return { UseCard, RespondCard, CardEffect }
