-- SPDX-License-Identifier: GPL-3.0-or-later

---@class UseCardEventWrappers: Object
local UseCardEventWrappers = {} -- mixin

---@return boolean
local function exec(tp, ...)
  local event = tp:create(...)
  local _, ret = event:exec()
  return ret
end


--- 播放使用/打出卡牌的声音和特效
---@param player ServerPlayer @ 使用者
---@param card Card @ 使用的牌
function UseCardEventWrappers:playCardEmotionAndSound(player, card)
  ---@cast self Room
  if card.type ~= Card.TypeEquip then
    local anim_path = "./packages/" .. card.package.extensionName .. "/image/anim/" .. card.name
    if not FileIO.exists(anim_path) then
      for _, dir in ipairs(FileIO.ls("./packages/")) do
        anim_path = "./packages/" .. dir .. "/image/anim/" .. card.name
        if FileIO.exists(anim_path) then break end
      end
    end
    if FileIO.exists(anim_path) then self:setEmotion(player, anim_path) end
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
  self:broadcastPlaySound(soundName)
end


--- 播放使用卡牌的信息（此步骤在使用牌移至处理区前）
---@param room Room
---@param useCardData UseCardData
---@param muteEmotion? boolean @ 是否不播放特效和语音
local sendCardEmotionAndLog = function(room, useCardData, muteEmotion)
  local from = useCardData.from
  local card = useCardData.card

  if not card:isVirtual() then
    card = room:filterCard(card.id, from)
  end

  if not muteEmotion then room:playCardEmotionAndSound(from, card)end

  -- 发送目标指示线
  if not useCardData.noIndicate then
    local tosData
    if useCardData.tos then
      tosData = {}
      for _, p in ipairs(useCardData.tos) do
        local sub = table.map(useCardData:getSubTos(p), Util.IdMapper)
        table.insert(tosData, { p.id, table.unpack(sub) })
      end
    end
    room:doAnimate("Indicate", {
      from = from.id,
      to = tosData or Util.DummyTable,
    })
  end

  if useCardData.tos and #useCardData.tos > 0 and not useCardData.noIndicate then
    local to = {}
    for _, p in ipairs(useCardData.tos) do
      table.insert(to, p.id)
    end

    room:sendLog{
      type = "#UseCardToTargets",
      from = from.id,
      to = to,
      card = { card }
    }

    -- 声明子目标
    for _, p in ipairs(useCardData.tos) do
      local subt = useCardData:getSubTos(p)
      if #subt > 0 then
        room:sendLog{
          type = "#CardUseCollaborator",
          from = p.id,
          to = table.map(subt, Util.IdMapper),
          arg = card,
        }
      end
    end
    -- 因响应而使用牌
  elseif useCardData.toCard then
    room:sendLog{
      type = "#UseCardToCard",
      from = from.id,
      card = { card },
      arg = useCardData.toCard,
    }
  else
    room:sendLog{
      type = "#UseCard",
      from = from.id,
      card = { card },
    }
  end
end

---@class GameEvent.UseCard : GameEvent
---@field public data UseCardData
local UseCard = GameEvent:subclass("GameEvent.UseCard")

function UseCard:__tostring()
  local data = self.data
  return string.format("<UseCard %s: %s => [%s] #%d>",
    data.card, data.from, table.concat(
      table.map(data.tos or {}, ServerPlayer.__tostring), ", "), self.id)
end

function UseCard:main()
  local useCardData = self.data
  local room = self.room
  local logic = room.logic

  if useCardData.attachedSkillAndUser then
    local skill = Fk.skills[useCardData.attachedSkillAndUser.skillName]--[[@as ViewAsSkill]]
    local user = room:getPlayerById(useCardData.attachedSkillAndUser.user)
    if skill and skill.afterUse then
      self:addExitFunc(function()
        skill:afterUse(user, useCardData)
      end)
    end
    -- useCardData.attachedSkillAndUser = nil
  end

  -- add fix targets to usedata in place of card.skill:onUse
  if #useCardData.tos == 0 then
    local fix_targets = useCardData.card:getFixedTargets(useCardData.from, useCardData.extra_data)
    if fix_targets then
      for _, p in ipairs(useCardData.card:getAvailableTargets(useCardData.from, useCardData.extra_data)) do
        useCardData:addTarget(p)
      end
    end
  end

  if useCardData.card.skill then
    useCardData.card.skill:onUse(room, useCardData)
  end

  if useCardData.card.type == Card.TypeEquip then
    local targets = useCardData.tos
    if #targets == 1 then
      local target = targets[1]
      local subType = useCardData.card.sub_type
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
        useCardData.toPutSlot = room:askToChoice(target, { choices = choices, skill_name = "replace_equip", prompt = "#GameRuleReplaceEquipment" })
      end
    end
  end

  if logic:trigger(fk.PreCardUse, useCardData.from, useCardData) then
    logic:breakEvent()
  end

  sendCardEmotionAndLog(room, useCardData, (useCardData.attachedSkillAndUser or {}).muteCard)

  room:moveCardTo(useCardData.card, Card.Processing, nil, fk.ReasonUse)

  local card = useCardData.card
  local useCardIds = Card:getIdList(card)
  local footnote
  if useCardData.tos and #useCardData.tos > 0 and #useCardData.tos <= 2 and not useCardData.noIndicate then
    local tos = table.map(useCardData.tos, Util.IdMapper)
    footnote = {
      type = "##UseCardTo",
      from = useCardData.from.id,
      to = tos,
    }
  else
    footnote = {
      type = "##UseCard",
      from = useCardData.from.id,
    }
  end
  if #useCardIds > 0 then
    room:sendFootnote(useCardIds, footnote)
    if card:isVirtual() or card.name ~= Fk:getCardById(card.id, true).name then
      room:sendCardVirtName(useCardIds, card.name)
    end
  else
    room:getVirtCardId(useCardData.card)
    room:showVirtualCard(useCardData.card, useCardData.from, footnote, self.id)
  end

  if not useCardData.extraUse then
    useCardData.from:addCardUseHistory(useCardData.card.trueName, 1)
  end

  if useCardData.responseToEvent then
    useCardData.responseToEvent.cardsResponded = useCardData.responseToEvent.cardsResponded or {}
    table.insertIfNeed(useCardData.responseToEvent.cardsResponded, useCardData.card)
  end

  for _, event in ipairs({ fk.AfterCardUseDeclared, fk.AfterCardTargetDeclared, fk.CardUsing }) do
    if not useCardData.toCard and #useCardData.tos == 0 then
      break
    end

    logic:trigger(event, useCardData.from, useCardData)
    if event == fk.CardUsing then
      if not useCardData.toCard and #useCardData.tos == 0 then
        break
      end

      room:doCardUseEffect(useCardData)
    end
  end
end

function UseCard:clear()
  local useCardData = self.data
  local room = self.room

  room.logic:trigger(fk.CardUseFinished, useCardData.from, useCardData)

  local leftRealCardIds = room:getSubcardsByRule(useCardData.card, { Card.Processing })
  if #leftRealCardIds > 0 then
    room:moveCards({
      ids = leftRealCardIds,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonUse,
    })
  end
  room:destroyTableCardByEvent(self.id)
end

---@class GameEvent.RespondCard : GameEvent
---@field public data RespondCardData
local RespondCard = GameEvent:subclass("GameEvent.RespondCard")

function RespondCard:__tostring()
  local data = self.data
  return string.format("<RespondCard %s: %s #%d>",
    data.card, data.from, self.id)
end

function RespondCard:main()
  local respondCardData = self.data
  local room = self.room
  local logic = room.logic

  if respondCardData.attachedSkillAndUser then
    local skill = Fk.skills[respondCardData.attachedSkillAndUser.skillName]--[[@as ViewAsSkill]]
    local user = room:getPlayerById(respondCardData.attachedSkillAndUser.user)
    if skill and skill.afterResponse then
      self:addExitFunc(function()
        skill:afterResponse(user, respondCardData)
      end)
    end
    -- respondCardData.attachedSkillAndUser = nil
  end

  if logic:trigger(fk.PreCardRespond, respondCardData.from, respondCardData) then
    logic:breakEvent()
  end

  if not respondCardData.card:isVirtual() then
    respondCardData.card = room:filterCard(respondCardData.card.id, respondCardData.from)
  end

  local from = respondCardData.customFrom or respondCardData.from
  local card = respondCardData.card
  local cardIds = room:getSubcardsByRule(card)
  local isVirtual = card:isVirtual() or card.name ~= Fk:getCardById(card.id, true).name

  if not (respondCardData.attachedSkillAndUser or {}).muteCard then
    room:playCardEmotionAndSound(from, card)
  end

  room:sendLog{
    type = "#ResponsePlayCard",
    from = from.id,
    card = { card },
  }

  room:moveCardTo(card, Card.Processing, nil, fk.ReasonResponse)
  local footnote = {
    type = "##ResponsePlayCard",
    from = from.id,
  }
  if #cardIds > 0 then
    room:sendFootnote(cardIds, footnote)
    if isVirtual then
      room:sendCardVirtName(cardIds, card.name)
    end
  else
    room:getVirtCardId(respondCardData.card)
    room:showVirtualCard(respondCardData.card, respondCardData.from, footnote, self.id)
  end

  logic:trigger(fk.CardResponding, from, respondCardData)
end

function RespondCard:clear()
  local respondCardData = self.data
  local room = self.room

  room.logic:trigger(fk.CardRespondFinished, respondCardData.from, respondCardData)

  local realCardIds = room:getSubcardsByRule(respondCardData.card, { Card.Processing })
  if #realCardIds > 0 and not respondCardData.skipDrop then
    room:moveCards({
      ids = realCardIds,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonResponse,
    })
  end
  room:destroyTableCardByEvent(self.id)
end

---@class GameEvent.CardEffect : GameEvent
---@field public data CardEffectData
local CardEffect = GameEvent:subclass("GameEvent.CardEffect")

function CardEffect:__tostring()
  local data = self.data
  return string.format("<CardEffect %s: %s => [%s] #%d>",
    data.card, data.from, table.concat(
      table.map(data.tos or {}, ServerPlayer.__tostring), ", "), self.id)
end

function CardEffect:main()
  local cardEffectData = self.data
  local room = self.room
  local logic = room.logic

  if cardEffectData.card.skill:aboutToEffect(room, cardEffectData) then
    logic:breakEvent()
  end
  for _, event in ipairs({ fk.PreCardEffect, fk.BeforeCardEffect, fk.CardEffecting }) do

    local function effectCancellOutCheck(effect)
      if effect.isCancellOut then
        logic:trigger(fk.CardEffectCancelledOut, effect.from, effect)
        if effect.isCancellOut then
          logic:breakEvent()
        end
      end

      if
        not effect.toCard and
        (
          not (effect.to and effect.to:isAlive())
          or #room:deadPlayerFilter(effect.tos) == 0
        )
      then
        logic:breakEvent()
      end

      if effect:isNullified() then
        logic:breakEvent()
      end
    end

    effectCancellOutCheck(cardEffectData)

    if event == fk.PreCardEffect then
      logic:trigger(event, cardEffectData.from, cardEffectData)
    else
      logic:trigger(event, cardEffectData.to, cardEffectData)
    end

    effectCancellOutCheck(cardEffectData)

    room:handleCardEffect(event, cardEffectData)
  end
end

function CardEffect:clear()
  local cardEffectData = self.data
  if cardEffectData.isCancellOut then
    local room = self.room
    room:setCardEmotion(cid, "judgebad")
  end
  self.room.logic:trigger(fk.CardEffectFinished, cardEffectData.to, cardEffectData)
end


--- 根据卡牌使用数据，去实际使用这个卡牌。
---@param useCardData UseCardDataSpec @ 使用数据
---@return boolean
function UseCardEventWrappers:useCard(useCardData)
  -- local new_data
  -- if type(useCardData.from) == "number" or (useCardData.tos and useCardData.tos[1]
  --   and type(useCardData.tos[1][1]) == "number") then
  --   new_data = UseCardData:new({})
  --   new_data:loadLegacy(useCardData)
  -- else
  local new_data = UseCardData:new(useCardData)
  new_data.tos = new_data.tos or {}
  -- end
  return exec(UseCard, new_data)
end

---@param room Room
---@param useCardData UseCardData
---@param aimEventCollaborators table<ServerPlayer, AimData[]>
---@return boolean
local onAim = function(room, useCardData, aimEventCollaborators)
  local eventStages = { fk.TargetSpecifying, fk.TargetConfirming, fk.TargetSpecified, fk.TargetConfirmed }
  for _, stage in ipairs(eventStages) do
    if (not useCardData.tos) or #useCardData.tos == 0 then
      return false
    end

    room:sortByAction(useCardData.tos)
    local aimGroup = AimData:initAimGroup(useCardData.tos)

    local collaboratorsIndex = {}
    local firstTarget = true
    repeat
      local to = aimGroup[AimData.Undone][1]
      ---@type AimData
      local aimStruct
      local initialEvent = false
      collaboratorsIndex[to] = collaboratorsIndex[to] or 1

      if not aimEventCollaborators[to] or collaboratorsIndex[to] > #aimEventCollaborators[to] then
        aimStruct = AimData:new {
          from = useCardData.from,
          card = useCardData.card,
          to = to,
          use = useCardData,
          tos = aimGroup,
          firstTarget = firstTarget,
          extra_data = useCardData.extra_data,
        }

        local index = 1
        for i1, target in ipairs(useCardData.tos) do
          if index > collaboratorsIndex[to] then
            break
          end

          if #useCardData:getSubTos(target) > 0 then
            aimStruct.subTargets = table.simpleClone(useCardData:getSubTos(target))
          else
            aimStruct.subTargets = {}
          end
        end

        collaboratorsIndex[to] = 1
        initialEvent = true
      else
        aimStruct = aimEventCollaborators[to][collaboratorsIndex[to]]
        aimStruct.from = useCardData.from
        aimStruct.card = useCardData.card
        aimStruct.tos = aimGroup
        aimStruct.firstTarget = firstTarget
        aimStruct.extra_data = useCardData.extra_data
      end

      firstTarget = false

      room.logic:trigger(stage, (stage == fk.TargetSpecifying or stage == fk.TargetSpecified) and aimStruct.from or aimStruct.to, aimStruct)

      aimStruct:removeDeadTargets()

      -- FIXME: 这段不该注释 我只是实在懒得改了
      -- local aimEventTargetGroup = aimStruct.targetGroup
      -- if aimEventTargetGroup then
      --   room:sortByAction(aimEventTargetGroup, true)
      -- end

      useCardData.from = aimStruct.from
      useCardData.card = aimStruct.card
      useCardData.extra_data = aimStruct.extra_data

      if #aimStruct:getAllTargets() == 0 then
        return false
      end

      local cancelledTargets = aimStruct:getCancelledTargets()
      if #cancelledTargets > 0 then
        for _, target in ipairs(cancelledTargets) do
          aimEventCollaborators[target] = {}
          collaboratorsIndex[target] = 1
        end
      end
      aimStruct.tos[AimData.Cancelled] = {}

      if to:isAlive() and not table.contains(cancelledTargets, to) then
        aimEventCollaborators[to] = aimEventCollaborators[to] or {}
        if aimStruct.cancelled then
          if not initialEvent then
            table.remove(aimEventCollaborators[to], collaboratorsIndex[to])
          end
        else
          if initialEvent then
            table.insert(aimEventCollaborators[to], aimStruct)
          else
            aimEventCollaborators[to][collaboratorsIndex[to]] = aimStruct
          end
          collaboratorsIndex[to] = collaboratorsIndex[to] + 1
          aimStruct:setTargetDone(to)
        end
      end

      aimGroup = aimStruct.tos
    until #aimGroup[AimData.Undone] == 0
  end

  return true
end

--- 对卡牌使用数据进行生效
---@param useCardData UseCardData
function UseCardEventWrappers:doCardUseEffect(useCardData)
  ---@cast self Room
  ---@type table<ServerPlayer, AimData[]>
  local aimEventCollaborators = {}
  if #useCardData.tos > 0 and not onAim(self, useCardData, aimEventCollaborators) then
    return
  end

  local realCardIds = self:getSubcardsByRule(useCardData.card, { Card.Processing })

  self.logic:trigger(fk.BeforeCardUseEffect, useCardData.from, useCardData)
  -- If using Equip or Delayed trick, move them to the area and return
  if useCardData.card.type == Card.TypeEquip then
    if #realCardIds == 0 then
      return
    end

    local target = useCardData.tos[1]
    if target and not target.dead and aimEventCollaborators[target] and not aimEventCollaborators[target][1]:isNullified() then
      local existingEquipId
      if useCardData.toPutSlot and useCardData.toPutSlot:startsWith("#EquipmentChoice") then
        local index = useCardData.toPutSlot:split(":")[2]
        existingEquipId = target:getEquipments(useCardData.card.sub_type)[tonumber(index)]
      elseif not target:hasEmptyEquipSlot(useCardData.card.sub_type) then
        existingEquipId = target:getEquipment(useCardData.card.sub_type)
      end

      local move = { ---@type CardsMoveInfo
        ids = realCardIds,
        to = target,
        toArea = Card.PlayerEquip,
        moveReason = fk.ReasonUse,
      }
      if Fk:getCardById(realCardIds[1], true).name ~= useCardData.card.name then
        -- 当锁定视为某个装备牌时，这里强行套虚拟卡，以适配智慧
        if not useCardData.card:isVirtual() then
          local vcard = Fk:cloneCard(useCardData.card.name)
          vcard:addSubcard(realCardIds[1])
          useCardData.card = vcard
        end
        move.virtualEquip = useCardData.card
      end

      if existingEquipId then
        self:moveCards(
          {
            ids = { existingEquipId },
            from = target,
            toArea = Card.DiscardPile,
            moveReason = fk.ReasonPutIntoDiscardPile,
          },
          move
        )
      else
        self:moveCards(move)
      end
    end

    return
  elseif useCardData.card.sub_type == Card.SubtypeDelayedTrick then
    if #realCardIds == 0 then
      return
    end

    local target = useCardData.tos[1]
    if not target.dead and aimEventCollaborators[target] and not aimEventCollaborators[target][1]:isNullified() then

      if not table.contains(target.sealedSlots, Player.JudgeSlot) and
       (useCardData.card.stackable_delayed or not target:hasDelayedTrick(useCardData.card.name)) then
        local move = { ---@type CardsMoveInfo
          ids = realCardIds,
          to = target,
          toArea = Card.PlayerJudge,
          moveReason = fk.ReasonUse,
        }
        if useCardData.card:isVirtual() or Fk:getCardById(realCardIds[1], true).name ~= useCardData.card.name then
          local vcard = Fk:cloneCard(useCardData.card.name, useCardData.card.suit, useCardData.card.number)
          vcard:addSubcard(realCardIds[1])
          vcard.skillNames = useCardData.card.skillNames
          move.virtualEquip = vcard
        end

        self:moveCards(move)

        return
      end
    end

    return
  end

  if not useCardData.card.skill then
    return
  end

  -- If using card to other card (like jink or nullification), simply effect and return
  if useCardData.toCard ~= nil then
    local cardEffectData = CardEffectData:new{
      from = useCardData.from,
      tos = useCardData.tos,
      subTos = useCardData.subTos,
      card = useCardData.card,
      toCard = useCardData.toCard,
      use = useCardData,
      responseToEvent = useCardData.responseToEvent,
      additionalDamage = useCardData.additionalDamage,
      additionalRecover = useCardData.additionalRecover,
      cardsResponded = useCardData.cardsResponded,
      prohibitedCardNames = useCardData.prohibitedCardNames,
      extra_data = useCardData.extra_data,
    }
    self:doCardEffect(cardEffectData)

    if cardEffectData.cardsResponded then
      useCardData.cardsResponded = useCardData.cardsResponded or {}
      for _, card in ipairs(cardEffectData.cardsResponded) do
        table.insertIfNeed(useCardData.cardsResponded, card)
      end
    end
    return
  end

  useCardData.additionalEffect = useCardData.additionalEffect or 0
  while true do
    if #useCardData.tos > 0 and useCardData.card.skill.onAction then
      useCardData.card.skill:onAction(self, useCardData)
    end

    -- Else: do effect to all targets
    local collaboratorsIndex = {}
    for _, to in ipairs(useCardData.tos) do
      if to:isAlive() then
        ---@class CardEffectDataSpec
        local cardEffectData = {
          from = useCardData.from,
          tos = useCardData.tos,
          subTos = useCardData.subTos,
          card = useCardData.card,
          toCard = useCardData.toCard,
          use = useCardData,
          responseToEvent = useCardData.responseToEvent,
          additionalDamage = useCardData.additionalDamage,
          additionalRecover = useCardData.additionalRecover,
          cardsResponded = useCardData.cardsResponded,
          prohibitedCardNames = useCardData.prohibitedCardNames,
          extra_data = useCardData.extra_data,
        }

        if aimEventCollaborators[to] then
          cardEffectData.to = to
          collaboratorsIndex[to] = collaboratorsIndex[to] or 1
          local curAimEvent = aimEventCollaborators[to][collaboratorsIndex[to]]

          cardEffectData.subTargets = curAimEvent.subTargets
          if curAimEvent.additionalDamage then
            cardEffectData.additionalDamage = (cardEffectData.additionalDamage or 0) + curAimEvent.additionalDamage
          end
          if curAimEvent.additionalRecover then
            cardEffectData.additionalRecover = (cardEffectData.additionalRecover or 0) + curAimEvent.additionalRecover
          end
          cardEffectData.disresponsive = curAimEvent.disresponsive
          cardEffectData.unoffsetable = curAimEvent.unoffsetable
          cardEffectData.nullified = curAimEvent.nullified
          cardEffectData.fixedResponseTimesList = curAimEvent.fixedResponseTimesList

          collaboratorsIndex[to] = collaboratorsIndex[to] + 1

          local curCardEffectEvent = CardEffectData:new(table.simpleClone(cardEffectData))
          self:doCardEffect(curCardEffectEvent)

          if curCardEffectEvent.cardsResponded then
            useCardData.cardsResponded = useCardData.cardsResponded or {}
            for _, card in ipairs(curCardEffectEvent.cardsResponded) do
              table.insertIfNeed(useCardData.cardsResponded, card)
            end
          end

        end
      end
    end

    if #useCardData.tos > 0 and useCardData.card.skill.onAction then
      useCardData.card.skill:onAction(self, useCardData, true)
    end

    if useCardData.additionalEffect > 0 then
      useCardData.additionalEffect = useCardData.additionalEffect - 1
    else
      break
    end
  end
end

--- 对卡牌效果数据进行生效
---@param cardEffectData CardEffectData
function UseCardEventWrappers:doCardEffect(cardEffectData)
  return exec(CardEffect, cardEffectData)
end

---@param event CardEffectEvent
---@param cardEffectData CardEffectData
function UseCardEventWrappers:handleCardEffect(event, cardEffectData)
  ---@cast self Room
  if event == fk.PreCardEffect then
    cardEffectData.card.skill:preEffect(self, cardEffectData)
  elseif event == fk.CardEffecting then
    if cardEffectData.card.skill then
      local data = { ---@type SkillEffectDataSpec
        who = cardEffectData.from,
        skill = cardEffectData.card.skill,
        skill_cb = function ()
          cardEffectData.card.skill:onEffect(self, cardEffectData)
        end,
        skill_data = Util.DummyTable
      }
      exec(GameEvent.SkillEffect, SkillEffectData:new(data))
    end
  end
end

--- 对“打出牌”进行处理
---@param responseCardData RespondCardDataSpec
function UseCardEventWrappers:responseCard(responseCardData)
  local new_data = RespondCardData:new(responseCardData)
  -- if type(new_data.from) == "number" then
  --   new_data:loadLegacy(responseCardData)
  -- end
  return exec(RespondCard, new_data)
end

--- 令角色对某些目标使用虚拟卡牌，会检测使用和目标合法性。不合法则返回nil
---@param card_name string @ 想要视为使用的牌名
---@param subcards? integer[] @ 子卡，可以留空或者直接nil
---@param from ServerPlayer @ 使用来源
---@param tos ServerPlayer | ServerPlayer[] @ 目标角色（列表）
---@param skillName? string @ 技能名
---@param extra? boolean @ 是否不计入次数
---@param extra_data? table @ 使用事件的extra_data
---@return UseCardDataSpec?
function UseCardEventWrappers:useVirtualCard(card_name, subcards, from, tos, skillName, extra, extra_data)
  local card = Fk:cloneCard(card_name)
  if skillName then card.skillName = skillName end

  if from:prohibitUse(card) then return nil end

  if not tos[1] then tos = { tos } end
  for i = #tos, 1, -1 do
    local p = tos[i]
    if from:isProhibited(p, card) then
      table.remove(tos, i)
    end
  end

  if #tos == 0 then return nil end

  if subcards then card:addSubcards(Card:getIdList(subcards)) end

  local use = { ---@type UseCardDataSpec
    from = from,
    tos = tos,
    card = card,
    extraUse = extra,
    extra_data = extra_data,
  }
  self:useCard(use)

  return use
end

return { UseCard, RespondCard, CardEffect, UseCardEventWrappers }
