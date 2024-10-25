-- SPDX-License-Identifier: GPL-3.0-or-later

---@class UseCardEventWrappers: Object
local UseCardEventWrappers = {} -- mixin

---@return boolean
local function exec(tp, ...)
  local event = tp:create(...)
  local _, ret = event:exec()
  return ret
end

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


--- 根据卡牌使用数据，去实际使用这个卡牌。
---@param cardUseEvent CardUseStruct @ 使用数据
---@return boolean
function UseCardEventWrappers:useCard(cardUseEvent)
  return exec(UseCard, cardUseEvent)
end

---@param room Room
---@param cardUseEvent CardUseStruct
---@param aimEventCollaborators table<string, AimStruct[]>
---@return boolean
local onAim = function(room, cardUseEvent, aimEventCollaborators)
  local eventStages = { fk.TargetSpecifying, fk.TargetConfirming, fk.TargetSpecified, fk.TargetConfirmed }
  for _, stage in ipairs(eventStages) do
    if (not cardUseEvent.tos) or #cardUseEvent.tos == 0 then
      return false
    end

    room:sortPlayersByAction(cardUseEvent.tos, true)
    local aimGroup = AimGroup:initAimGroup(TargetGroup:getRealTargets(cardUseEvent.tos))

    local collaboratorsIndex = {}
    local firstTarget = true
    repeat
      local toId = AimGroup:getUndoneOrDoneTargets(aimGroup)[1]
      ---@type AimStruct
      local aimStruct
      local initialEvent = false
      collaboratorsIndex[toId] = collaboratorsIndex[toId] or 1

      if not aimEventCollaborators[toId] or collaboratorsIndex[toId] > #aimEventCollaborators[toId] then
        aimStruct = {
          from = cardUseEvent.from,
          card = cardUseEvent.card,
          to = toId,
          targetGroup = cardUseEvent.tos,
          nullifiedTargets = cardUseEvent.nullifiedTargets or {},
          tos = aimGroup,
          firstTarget = firstTarget,
          additionalDamage = cardUseEvent.additionalDamage,
          additionalRecover = cardUseEvent.additionalRecover,
          additionalEffect = cardUseEvent.additionalEffect,
          extra_data = cardUseEvent.extra_data,
        }

        local index = 1
        for _, targets in ipairs(cardUseEvent.tos) do
          if index > collaboratorsIndex[toId] then
            break
          end

          if #targets > 1 then
            for i = 2, #targets do
              aimStruct.subTargets = {}
              table.insert(aimStruct.subTargets, targets[i])
            end
          end
        end

        collaboratorsIndex[toId] = 1
        initialEvent = true
      else
        aimStruct = aimEventCollaborators[toId][collaboratorsIndex[toId]]
        aimStruct.from = cardUseEvent.from
        aimStruct.card = cardUseEvent.card
        aimStruct.tos = aimGroup
        aimStruct.targetGroup = cardUseEvent.tos
        aimStruct.nullifiedTargets = cardUseEvent.nullifiedTargets or {}
        aimStruct.firstTarget = firstTarget
        aimStruct.additionalEffect = cardUseEvent.additionalEffect
        aimStruct.extra_data = cardUseEvent.extra_data
      end

      firstTarget = false

      room.logic:trigger(stage, (stage == fk.TargetSpecifying or stage == fk.TargetSpecified) and room:getPlayerById(aimStruct.from) or room:getPlayerById(aimStruct.to), aimStruct)

      AimGroup:removeDeadTargets(room, aimStruct)

      local aimEventTargetGroup = aimStruct.targetGroup
      if aimEventTargetGroup then
        room:sortPlayersByAction(aimEventTargetGroup, true)
      end

      cardUseEvent.from = aimStruct.from
      cardUseEvent.tos = aimEventTargetGroup
      cardUseEvent.nullifiedTargets = aimStruct.nullifiedTargets
      cardUseEvent.additionalEffect = aimStruct.additionalEffect
      cardUseEvent.extra_data = aimStruct.extra_data

      if #AimGroup:getAllTargets(aimStruct.tos) == 0 then
        return false
      end

      local cancelledTargets = AimGroup:getCancelledTargets(aimStruct.tos)
      if #cancelledTargets > 0 then
        for _, target in ipairs(cancelledTargets) do
          aimEventCollaborators[target] = {}
          collaboratorsIndex[target] = 1
        end
      end
      aimStruct.tos[AimGroup.Cancelled] = {}

      aimEventCollaborators[toId] = aimEventCollaborators[toId] or {}
      if room:getPlayerById(toId):isAlive() then
        if initialEvent then
          table.insert(aimEventCollaborators[toId], aimStruct)
        else
          aimEventCollaborators[toId][collaboratorsIndex[toId]] = aimStruct
        end

        collaboratorsIndex[toId] = collaboratorsIndex[toId] + 1
      end

      AimGroup:setTargetDone(aimStruct.tos, toId)
      aimGroup = aimStruct.tos
    until #AimGroup:getUndoneOrDoneTargets(aimGroup) == 0
  end

  return true
end

--- 对卡牌使用数据进行生效
---@param cardUseEvent CardUseStruct
function UseCardEventWrappers:doCardUseEffect(cardUseEvent)
  ---@type table<string, AimStruct>
  local aimEventCollaborators = {}
  if cardUseEvent.tos and not onAim(self, cardUseEvent, aimEventCollaborators) then
    return
  end

  local realCardIds = self:getSubcardsByRule(cardUseEvent.card, { Card.Processing })

  self.logic:trigger(fk.BeforeCardUseEffect, self:getPlayerById(cardUseEvent.from), cardUseEvent)
  -- If using Equip or Delayed trick, move them to the area and return
  if cardUseEvent.card.type == Card.TypeEquip then
    if #realCardIds == 0 then
      return
    end

    local target = TargetGroup:getRealTargets(cardUseEvent.tos)[1]
    if not (self:getPlayerById(target).dead or table.contains((cardUseEvent.nullifiedTargets or Util.DummyTable), target)) then
      local existingEquipId
      if cardUseEvent.toPutSlot and cardUseEvent.toPutSlot:startsWith("#EquipmentChoice") then
        local index = cardUseEvent.toPutSlot:split(":")[2]
        existingEquipId = self:getPlayerById(target):getEquipments(cardUseEvent.card.sub_type)[tonumber(index)]
      elseif not self:getPlayerById(target):hasEmptyEquipSlot(cardUseEvent.card.sub_type) then
        existingEquipId = self:getPlayerById(target):getEquipment(cardUseEvent.card.sub_type)
      end

      if existingEquipId then
        self:moveCards(
          {
            ids = { existingEquipId },
            from = target,
            toArea = Card.DiscardPile,
            moveReason = fk.ReasonPutIntoDiscardPile,
          },
          {
            ids = realCardIds,
            to = target,
            toArea = Card.PlayerEquip,
            moveReason = fk.ReasonUse,
          }
        )
      else
        self:moveCards({
          ids = realCardIds,
          to = target,
          toArea = Card.PlayerEquip,
          moveReason = fk.ReasonUse,
        })
      end
    end

    return
  elseif cardUseEvent.card.sub_type == Card.SubtypeDelayedTrick then
    if #realCardIds == 0 then
      return
    end

    local target = TargetGroup:getRealTargets(cardUseEvent.tos)[1]
    if not (self:getPlayerById(target).dead or table.contains((cardUseEvent.nullifiedTargets or Util.DummyTable), target)) then
      local findSameCard = false
      for _, cardId in ipairs(self:getPlayerById(target):getCardIds(Player.Judge)) do
        if Fk:getCardById(cardId).trueName == cardUseEvent.card.trueName then
          findSameCard = true
        end
      end

      if not findSameCard then
        if cardUseEvent.card:isVirtual() then
          self:getPlayerById(target):addVirtualEquip(cardUseEvent.card)
        elseif cardUseEvent.card.name ~= Fk:getCardById(cardUseEvent.card.id, true).name then
          local card = Fk:cloneCard(cardUseEvent.card.name)
          card.skillNames = cardUseEvent.card.skillNames
          card:addSubcard(cardUseEvent.card.id)
          self:getPlayerById(target):addVirtualEquip(card)
        else
          self:getPlayerById(target):removeVirtualEquip(cardUseEvent.card.id)
        end

        self:moveCards({
          ids = realCardIds,
          to = target,
          toArea = Card.PlayerJudge,
          moveReason = fk.ReasonUse,
        })

        return
      end
    end

    return
  end

  if not cardUseEvent.card.skill then
    return
  end

  -- If using card to other card (like jink or nullification), simply effect and return
  if cardUseEvent.toCard ~= nil then
    ---@class CardEffectEvent
    local cardEffectEvent = {
      from = cardUseEvent.from,
      tos = cardUseEvent.tos,
      card = cardUseEvent.card,
      toCard = cardUseEvent.toCard,
      responseToEvent = cardUseEvent.responseToEvent,
      nullifiedTargets = cardUseEvent.nullifiedTargets,
      disresponsiveList = cardUseEvent.disresponsiveList,
      unoffsetableList = cardUseEvent.unoffsetableList,
      additionalDamage = cardUseEvent.additionalDamage,
      additionalRecover = cardUseEvent.additionalRecover,
      cardsResponded = cardUseEvent.cardsResponded,
      prohibitedCardNames = cardUseEvent.prohibitedCardNames,
      extra_data = cardUseEvent.extra_data,
    }
    self:doCardEffect(cardEffectEvent)

    if cardEffectEvent.cardsResponded then
      cardUseEvent.cardsResponded = cardUseEvent.cardsResponded or {}
      for _, card in ipairs(cardEffectEvent.cardsResponded) do
        table.insertIfNeed(cardUseEvent.cardsResponded, card)
      end
    end
    return
  end

  local i = 0
  while i < (cardUseEvent.additionalEffect or 0) + 1 do
    if #TargetGroup:getRealTargets(cardUseEvent.tos) > 0 and cardUseEvent.card.skill.onAction then
      cardUseEvent.card.skill:onAction(self, cardUseEvent)
    end

    -- Else: do effect to all targets
    local collaboratorsIndex = {}
    for _, toId in ipairs(TargetGroup:getRealTargets(cardUseEvent.tos)) do
      if not table.contains(cardUseEvent.nullifiedTargets, toId) and self:getPlayerById(toId):isAlive() then
        ---@class CardEffectEvent
        local cardEffectEvent = {
          from = cardUseEvent.from,
          tos = cardUseEvent.tos,
          card = cardUseEvent.card,
          toCard = cardUseEvent.toCard,
          responseToEvent = cardUseEvent.responseToEvent,
          nullifiedTargets = cardUseEvent.nullifiedTargets,
          disresponsiveList = cardUseEvent.disresponsiveList,
          unoffsetableList = cardUseEvent.unoffsetableList,
          additionalDamage = cardUseEvent.additionalDamage,
          additionalRecover = cardUseEvent.additionalRecover,
          cardsResponded = cardUseEvent.cardsResponded,
          prohibitedCardNames = cardUseEvent.prohibitedCardNames,
          extra_data = cardUseEvent.extra_data,
        }

        if aimEventCollaborators[toId] then
          cardEffectEvent.to = toId
          collaboratorsIndex[toId] = collaboratorsIndex[toId] or 1
          local curAimEvent = aimEventCollaborators[toId][collaboratorsIndex[toId]]

          cardEffectEvent.subTargets = curAimEvent.subTargets
          cardEffectEvent.additionalDamage = curAimEvent.additionalDamage
          cardEffectEvent.additionalRecover = curAimEvent.additionalRecover

          if curAimEvent.disresponsiveList then
            cardEffectEvent.disresponsiveList = cardEffectEvent.disresponsiveList or {}

            for _, disresponsivePlayer in ipairs(curAimEvent.disresponsiveList) do
              if not table.contains(cardEffectEvent.disresponsiveList, disresponsivePlayer) then
                table.insert(cardEffectEvent.disresponsiveList, disresponsivePlayer)
              end
            end
          end

          if curAimEvent.unoffsetableList then
            cardEffectEvent.unoffsetableList = cardEffectEvent.unoffsetableList or {}

            for _, unoffsetablePlayer in ipairs(curAimEvent.unoffsetableList) do
              if not table.contains(cardEffectEvent.unoffsetableList, unoffsetablePlayer) then
                table.insert(cardEffectEvent.unoffsetableList, unoffsetablePlayer)
              end
            end
          end

          cardEffectEvent.disresponsive = curAimEvent.disresponsive
          cardEffectEvent.unoffsetable = curAimEvent.unoffsetable
          cardEffectEvent.fixedResponseTimes = curAimEvent.fixedResponseTimes
          cardEffectEvent.fixedAddTimesResponsors = curAimEvent.fixedAddTimesResponsors

          collaboratorsIndex[toId] = collaboratorsIndex[toId] + 1

          local curCardEffectEvent = table.simpleClone(cardEffectEvent)
          self:doCardEffect(curCardEffectEvent)

          if curCardEffectEvent.cardsResponded then
            cardUseEvent.cardsResponded = cardUseEvent.cardsResponded or {}
            for _, card in ipairs(curCardEffectEvent.cardsResponded) do
              table.insertIfNeed(cardUseEvent.cardsResponded, card)
            end
          end

          if type(curCardEffectEvent.nullifiedTargets) == 'table' then
            table.insertTableIfNeed(cardUseEvent.nullifiedTargets, curCardEffectEvent.nullifiedTargets)
          end
        end
      end
    end

    if #TargetGroup:getRealTargets(cardUseEvent.tos) > 0 and cardUseEvent.card.skill.onAction then
      cardUseEvent.card.skill:onAction(self, cardUseEvent, true)
    end

    i = i + 1
  end
end

--- 对卡牌效果数据进行生效
---@param cardEffectEvent CardEffectEvent
function UseCardEventWrappers:doCardEffect(cardEffectEvent)
  return exec(CardEffect, cardEffectEvent)
end

---@param cardEffectEvent CardEffectEvent
function UseCardEventWrappers:handleCardEffect(event, cardEffectEvent)
  if event == fk.PreCardEffect then
    if cardEffectEvent.card.skill:aboutToEffect(self, cardEffectEvent) then return end
    if
      cardEffectEvent.card.trueName == "slash" and
      not (cardEffectEvent.unoffsetable or table.contains(cardEffectEvent.unoffsetableList or Util.DummyTable, cardEffectEvent.to))
    then
      local loopTimes = 1
      if cardEffectEvent.fixedResponseTimes then
        if type(cardEffectEvent.fixedResponseTimes) == "table" then
          loopTimes = cardEffectEvent.fixedResponseTimes["jink"] or 1
        elseif type(cardEffectEvent.fixedResponseTimes) == "number" then
          loopTimes = cardEffectEvent.fixedResponseTimes
        end
      end
      Fk.currentResponsePattern = "jink"

      for i = 1, loopTimes do
        local to = self:getPlayerById(cardEffectEvent.to)
        local prompt = ""
        if cardEffectEvent.from then
          if loopTimes == 1 then
            prompt = "#slash-jink:" .. cardEffectEvent.from
          else
            prompt = "#slash-jink-multi:" .. cardEffectEvent.from .. "::" .. i .. ":" .. loopTimes
          end
        end

        local use = self:askForUseCard(
          to,
          "jink",
          nil,
          prompt,
          true,
          nil,
          cardEffectEvent
        )
        if use then
          use.toCard = cardEffectEvent.card
          use.responseToEvent = cardEffectEvent
          self:useCard(use)
        end

        if not cardEffectEvent.isCancellOut then
          break
        end

        cardEffectEvent.isCancellOut = i == loopTimes
      end
    elseif
      cardEffectEvent.card.type == Card.TypeTrick and
      not (cardEffectEvent.disresponsive or cardEffectEvent.unoffsetable) and
      not table.contains(cardEffectEvent.prohibitedCardNames or Util.DummyTable, "nullification")
    then
      local players = {}
      Fk.currentResponsePattern = "nullification"
      local cardCloned = Fk:cloneCard("nullification")
      for _, p in ipairs(self.alive_players) do
        if not p:prohibitUse(cardCloned) then
          local cards = p:getHandlyIds()
          for _, cid in ipairs(cards) do
            if
              Fk:getCardById(cid).trueName == "nullification" and
              not (
                table.contains(cardEffectEvent.disresponsiveList or Util.DummyTable, p.id) or
                table.contains(cardEffectEvent.unoffsetableList or Util.DummyTable, p.id)
              )
            then
              table.insert(players, p)
              break
            end
          end
          if not table.contains(players, p) then
            Self = p -- for enabledAtResponse
            for _, s in ipairs(table.connect(p.player_skills, p._fake_skills)) do
              if
                s.pattern and
                Exppattern:Parse("nullification"):matchExp(s.pattern) and
                not (s.enabledAtResponse and not s:enabledAtResponse(p)) and
                not (
                  table.contains(cardEffectEvent.disresponsiveList or Util.DummyTable, p.id) or
                  table.contains(cardEffectEvent.unoffsetableList or Util.DummyTable, p.id)
                )
              then
                table.insert(players, p)
                break
              end
            end
          end
        end
      end

      local prompt = ""
      if cardEffectEvent.to then
        prompt = "#AskForNullification::" .. cardEffectEvent.to .. ":" .. cardEffectEvent.card.name
      elseif cardEffectEvent.from then
        prompt = "#AskForNullificationWithoutTo:" .. cardEffectEvent.from .. "::" .. cardEffectEvent.card.name
      end

      local extra_data
      if #TargetGroup:getRealTargets(cardEffectEvent.tos) > 1 then
        local parentUseEvent = self.logic:getCurrentEvent():findParent(GameEvent.UseCard)
        if parentUseEvent then
          extra_data = { useEventId = parentUseEvent.id, effectTo = cardEffectEvent.to }
        end
      end
      local use = self:askForNullification(players, nil, nil, prompt, true, extra_data, cardEffectEvent)
      if use then
        use.toCard = cardEffectEvent.card
        use.responseToEvent = cardEffectEvent
        self:useCard(use)
      end
    end
    Fk.currentResponsePattern = nil
  elseif event == fk.CardEffecting then
    if cardEffectEvent.card.skill then
      exec(GameEvent.SkillEffect, function ()
        cardEffectEvent.card.skill:onEffect(self, cardEffectEvent)
      end, self:getPlayerById(cardEffectEvent.from), cardEffectEvent.card.skill)
    end
  end
end

--- 对“打出牌”进行处理
---@param cardResponseEvent CardResponseEvent
function UseCardEventWrappers:responseCard(cardResponseEvent)
  return exec(RespondCard, cardResponseEvent)
end

---@param card_name string @ 想要视为使用的牌名
---@param subcards? integer[] @ 子卡，可以留空或者直接nil
---@param from ServerPlayer @ 使用来源
---@param tos ServerPlayer | ServerPlayer[] @ 目标角色（列表）
---@param skillName? string @ 技能名
---@param extra? boolean @ 是否不计入次数
---@return CardUseStruct
function UseCardEventWrappers:useVirtualCard(card_name, subcards, from, tos, skillName, extra)
  local card = Fk:cloneCard(card_name)
  card.skillName = skillName

  if from:prohibitUse(card) then return false end

  if tos.class then tos = { tos } end
  for i, p in ipairs(tos) do
    if from:isProhibited(p, card) then
      table.remove(tos, i)
    end
  end

  if #tos == 0 then return false end

  if subcards then card:addSubcards(Card:getIdList(subcards)) end

  local use = {} ---@type CardUseStruct
  use.from = from.id
  use.tos = table.map(tos, function(p) return { p.id } end)
  use.card = card
  use.extraUse = extra
  self:useCard(use)

  return use
end

return { UseCard, RespondCard, CardEffect, UseCardEventWrappers }
