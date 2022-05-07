---@class Room : Object
---@field room fk.Room
---@field players ServerPlayer[]
---@field alive_players ServerPlayer[]
---@field current ServerPlayer
---@field game_finished boolean
---@field timeout integer
---@field tag table<string, any>
---@field draw_pile integer[]
---@field discard_pile integer[]
---@field processing_area integer[]
---@field void integer[]
---@field card_place table<integer, CardArea>
local Room = class("Room")

-- load classes used by the game
GameLogic = require "server.gamelogic"
ServerPlayer = require "server.serverplayer"

fk.room_callback = {}

---@param _room fk.Room
function Room:initialize(_room)
  self.room = _room
  self.room.callback = function(_self, command, jsonData)
    local cb = fk.room_callback[command]
    if (type(cb) == "function") then
      cb(jsonData)
    else
      print("Lobby error: Unknown command " .. command);
    end
  end

  self.room.startGame = function(_self)
    Room.initialize(self, _room)  -- clear old data  
    self:run()
  end

  self.players = {}
  self.alive_players = {}
  self.current = nil
  self.game_finished = false
  self.timeout = _room:getTimeout()
  self.tag = {}
  self.draw_pile = {}
  self.discard_pile = {}
  self.processing_area = {}
  self.void = {}
  self.card_place = {}
end

-- When this function returns, the Room(C++) thread stopped.
function Room:run()
  for _, p in fk.qlist(self.room:getPlayers()) do
    local player = ServerPlayer:new(p)
    player.room = self
    table.insert(self.players, player)
  end

  self.logic = GameLogic:new(self)
  self.logic:run()
end

---@param player ServerPlayer
---@param property string
function Room:broadcastProperty(player, property)
  for _, p in ipairs(self.players) do
    self:notifyProperty(p, player, property)
  end
end

---@param p ServerPlayer
---@param player ServerPlayer
---@param property string
function Room:notifyProperty(p, player, property)
  p:doNotify("PropertyUpdate", json.encode{
    player.id,
    property,
    player[property],
  })
end

---@param command string
---@param jsonData string
---@param players ServerPlayer[] | nil @ default all players
function Room:doBroadcastNotify(command, jsonData, players)
  players = players or self.players
  local tolist = fk.SPlayerList()
  for _, p in ipairs(players) do
    tolist:append(p.serverplayer)
  end
  self.room:doBroadcastNotify(tolist, command, jsonData)
end

---@param player ServerPlayer
---@param command string
---@param jsonData string
---@param wait boolean @ default true
---@return string | nil
function Room:doRequest(player, command, jsonData, wait)
  if wait == nil then wait = true end
  player:doRequest(command, jsonData, self.timeout)

  if wait then
    return player:waitForReply(self.timeout)
  end
end

---@param command string
---@param players ServerPlayer[]
function Room:doBroadcastRequest(command, players)
  players = players or self.players
  self:notifyMoveFocus(players, command)
  for _, p in ipairs(players) do
    self:doRequest(p, command, p.request_data, false)
  end

  local remainTime = self.timeout
  local currentTime = os.time()
  local elapsed = 0
  for _, p in ipairs(players) do
    elapsed = os.time() - currentTime
    remainTime = remainTime - elapsed
    p:waitForReply(remainTime)
  end
end

---@param players ServerPlayer | ServerPlayer[]
---@param command string
function Room:notifyMoveFocus(players, command)
  if (players.class) then
    players = {players}
  end

  local ids = {}
  for _, p in ipairs(players) do
    table.insert(ids, p.id)
  end

  self:doBroadcastNotify("MoveFocus", json.encode{
    ids,
    command
  })
end

function Room:adjustSeats()
  local players = {}
  local p = 0

  for i = 1, #self.players do
    if self.players[i].role == "lord" then
      p = i
      break
    end
  end
  for j = p, #self.players do
    table.insert(players, self.players[j])
  end
  for j = 1, p - 1 do
    table.insert(players, self.players[j])
  end

  self.players = players

  local player_circle = {}
  for i = 1, #self.players do
    self.players[i].seat = i
    table.insert(player_circle, self.players[i].id)
  end

  self:doBroadcastNotify("ArrangeSeats", json.encode(player_circle))
end

function Room:shuffleDrawPile()
  if #self.draw_pile + #self.discard_pile == 0 then
    return
  end

  table.insertTable(self.draw_pile, self.discard_pile)
  for _, id in ipairs(self.discard_pile) do
    self:setCardArea(id, Card.DrawPile)
  end
  self.discard_pile = {}
  table.shuffle(self.draw_pile)
end

---@param num integer
---@param from string
---@return integer[]
function Room:getNCards(num, from)
  from = from or "top"
  assert(from == "top" or from == "bottom")

  local cardIds = {}
  while num > 0 do
    if #self.draw_pile < 1 then
      self:shuffleDrawPile()
    end

    local index = from == "top" and 1 or #self.draw_pile
    table.insert(cardIds, self.draw_pile[index])
    table.remove(self.draw_pile, index)

    num = num - 1
  end

  return cardIds
end

---@param cardId integer
---@param cardArea CardArea
function Room:setCardArea(cardId, cardArea)
  self.card_place[cardId] = cardArea
end

---@param cardId integer
---@return CardArea
function Room:getCardArea(cardId)
  return self.card_place[cardId] or Card.Unknown
end

---@param players ServerPlayer[]
---@param card_moves CardsMoveStruct[]
---@param forceVisible boolean
function Room:notifyMoveCards(players, card_moves, forceVisible)
  if players == nil or players == {} then players = self.players end
  for _, p in ipairs(players) do
    local arg = table.clone(card_moves)
    for _, move in ipairs(arg) do
      -- local to = self:getPlayerById(move.to)

      -- forceVisible make the move visible
      -- FIXME: move.moveInfo is an array, fix this
      move.moveVisible = (forceVisible)
        -- if move is relevant to player, it should be open
        or ((move.from == p.id) or (move.to == p.id and move.toArea ~= Card.PlayerSpecial))
        -- cards move from/to equip/judge/discard/processing should be open
        or move.moveInfo.fromArea == Card.PlayerEquip
        or move.toArea == Card.PlayerEquip
        or move.moveInfo.fromArea == Card.PlayerJudge
        or move.toArea == Card.PlayerJudge
        or move.moveInfo.fromArea == Card.DiscardPile
        or move.toArea == Card.DiscardPile
        or move.moveInfo.fromArea == Card.Processing
        or move.toArea == Card.Processing
        -- TODO: PlayerSpecial
      
      if not move.moveVisible then
        for _, info in ipairs(move.moveInfo) do
          info.cardId = -1
        end
      end
    end
    p:doNotify("MoveCards", json.encode(arg))
  end
end

---@vararg CardsMoveInfo
---@return boolean
function Room:moveCards(...)
  ---@type CardsMoveStruct[]
  local cardsMoveStructs = {}
  local infoCheck = function(info)
    assert(table.contains({ Card.PlayerHand, Card.PlayerEquip, Card.PlayerJudge, Card.PlayerSpecial, Card.Processing, Card.DrawPile, Card.DiscardPile, Card.Void }, info.toArea))
    assert(info.toArea ~= Card.PlayerSpecial or type(info.specialName) == "string")
    assert(type(info.moveReason) == "number")
  end

  for _, cardsMoveInfo in ipairs({...}) do
    if #cardsMoveInfo.ids > 0 then
      infoCheck(cardsMoveInfo)

      ---@type MoveInfo[]
      local infos = {}
      for _, id in ipairs(cardsMoveInfo.ids) do
        table.insert(infos, { cardId = id, fromArea = self:getCardArea(id) })
      end
  
      ---@type CardsMoveStruct
      local cardsMoveStruct = {
        moveInfo = infos,
        from = cardsMoveInfo.from,
        to = cardsMoveInfo.to,
        toArea = cardsMoveInfo.toArea,
        moveReason = cardsMoveInfo.moveReason,
        proposer = cardsMoveInfo.proposer,
        skillName = cardsMoveInfo.skillName,
        moveVisible = cardsMoveInfo.moveVisible,
        specialName = cardsMoveInfo.specialName,
        specialVisible = cardsMoveInfo.specialVisible,
      }
  
      table.insert(cardsMoveStructs, cardsMoveStruct)
    end
  end

  if #cardsMoveStructs < 1 then
    return false
  end

  if self.logic:trigger(fk.BeforeCardsMove, nil, cardsMoveStructs) then
    return false
  end

  self:notifyMoveCards(self.players, cardsMoveStructs)

  for _, data in ipairs(cardsMoveStructs) do
    if #data.moveInfo > 0 then
      infoCheck(data)

      ---@param info MoveInfo
      for _, info in ipairs(data.moveInfo) do
        local realFromArea = self:getCardArea(info.cardId)
        local playerAreas = { Player.Hand, Player.Equip, Player.Judge, Player.Special }

        if table.contains(playerAreas, realFromArea) and data.from then
          self:getPlayerById(data.from):removeCards(realFromArea, { info.cardId }, data.specialName)
        elseif realFromArea ~= Card.Unknown then
          local fromAreaIds = {}
          if realFromArea == Card.Processing then
            fromAreaIds = self.processing_area
          elseif realFromArea == Card.DrawPile then
            fromAreaIds = self.draw_pile
          elseif realFromArea == Card.DiscardPile then
            fromAreaIds = self.discard_pile
          elseif realFromArea == Card.Void then
            fromAreaIds = self.void
          end

          table.removeOne(fromAreaIds, info.cardId)
        end

        if table.contains(playerAreas, data.toArea) and data.to then
          self:getPlayerById(data.to):addCards(data.toArea, { info.cardId }, data.specialName)
        else
          local toAreaIds = {}
          if data.toArea == Card.Processing then
            toAreaIds = self.processing_area
          elseif data.toArea == Card.DrawPile then
            toAreaIds = self.draw_pile
          elseif data.toArea == Card.DiscardPile then
            toAreaIds = self.discard_pile
          elseif data.toArea == Card.Void then
            toAreaIds = self.void
          end

          table.insert(toAreaIds, toAreaIds == Card.DrawPile and 1 or #toAreaIds + 1, info.cardId)
        end
        self:setCardArea(info.cardId, data.toArea)
      end
    end
  end

  self.logic:trigger(fk.AfterCardsMove, nil, cardsMoveStructs)
  return true
end

---@param player ServerPlayer
---@param num integer
---@param skillName string
---@param fromPlace "top"|"bottom"
---@return integer[]
function Room:drawCards(player, num, skillName, fromPlace)
  local topCards = self:getNCards(num, fromPlace)
  self:moveCards({
    ids = topCards,
    to = player.id,
    toArea = Card.PlayerHand,
    moveReason = fk.ReasonDraw,
    proposer = player.id,
    skillName = skillName,
  })

  return { table.unpack(topCards) }
end

---@param player ServerPlayer
---@param minNum integer
---@param maxNum integer
---@param includeEquip boolean
---@param skillName string
function Room:askForDiscard(player, minNum, maxNum, includeEquip, skillName)
  if minNum < 1 then
    return nil
  end

  local hands = player:getCardIds(Player.Hand)
  local toDiscard = {}
  for i = 1, minNum do
    local randomId = hands[math.random(1, #hands)]
    table.insert(toDiscard, randomId)
    table.removeOne(hands, randomId)
  end

  self:moveCards({
    ids = toDiscard,
    from = player.id,
    toArea = Card.DiscardPile,
    moveReason = fk.ReasonDiscard,
    proposer = player.id,
    skillName = skillName
  })
end

---@param id integer
---@return ServerPlayer
function Room:getPlayerById(id)
  assert(type(id) == "number")

  for _, p in ipairs(self.players) do
    if p.id == id then
      return p
    end
  end

  error("cannot find player by " .. id)
end

---@param playerIds integer[]
function Room:sortPlayersByAction(playerIds)

end

function Room:deadPlayerFilter(playerIds)
  local newPlayerIds = {}
  for _, playerId in ipairs(playerIds) do
    if self:getPlayerById(playerId):isAlive() then
      table.insert(newPlayerIds, playerId)
    end
  end

  return newPlayerIds
end

---@param sortBySeat boolean
---@return ServerPlayer[]
function Room:getAlivePlayers(sortBySeat)
  sortBySeat = sortBySeat or true

  local alivePlayers = {}
  for _, player in ipairs(self.players) do
    if player:isAlive() then
      table.insert(alivePlayers, player)
    end
  end

  return alivePlayers
end

---@param player ServerPlayer
---@param sortBySeat boolean
---@return ServerPlayer[]
function Room:getOtherPlayers(player, sortBySeat)
  local alivePlayers = self:getAlivePlayers(sortBySeat)
  for _, p in ipairs(alivePlayers) do
    if p.id == player.id then
      table.removeOne(alivePlayers, player)
      break
    end
  end

  return alivePlayers
end

---@return ServerPlayer | null
function Room:getLord()
  local lord = self.players[1]
  if lord.role == "lord" then return lord end
  for _, p in ipairs(self.players) do
    if p.role == "lord" then return p end
  end

  return nil
end

---@param expect ServerPlayer
---@return ServerPlayer[]
function Room:getOtherPlayers(expect)
  local ret = {table.unpack(self.players)}
  table.removeOne(ret, expect)
  return ret
end

---@param player ServerPlayer
---@param generals string[]
---@return string
function Room:askForGeneral(player, generals)
  local command = "AskForGeneral"
  self:notifyMoveFocus(player, command)

  if #generals == 1 then return generals[1] end
  local defaultChoice = generals[1]

  if (player.state == "online") then
    local result = self:doRequest(player, command, json.encode(generals))
    if result == "" then
      return defaultChoice
    else
      -- TODO: result is a JSON array
      -- update here when choose multiple generals
      return json.decode(result)[1]
    end
  end

  return defaultChoice
end

---@param chooser ServerPlayer
---@param target ServerPlayer
---@param flag string @ "hej", h for handcard, e for equip, j for judge
---@param reason string
function Room:askForCardChosen(chooser, target, flag, reason)
  local command = "AskForCardChosen"
  self:notifyMoveFocus(chooser, command)
  local data = {target.id, flag, reason}
  local result = self:doRequest(chooser, command, json.encode(data))

  if result == "" then
    -- FIXME: generate a random card according to flag
    result = -1
  else
    result = tonumber(result)
  end

  if result == -1 then
    local handcards = target.player_cards[Player.Hand]
    result = handcards[math.random(1, #handcards)]
  end

  return result
end

function Room:gameOver()
  self.game_finished = true
  -- dosomething
  self.room:gameOver()
end

---@param player ServerPlayer
---@param choices string[]
---@param skill_name string
function Room:askForChoice(player, choices, skill_name, data)
  if #choices == 1 then return choices[1] end
  local command = "AskForChoice"
  self:notifyMoveFocus(player, skill_name)
  local result = self:doRequest(player, command, json.encode{
    choices, skill_name
  })
  if result == "" then result = choices[1] end
  return result
end

---@param player ServerPlayer
---@param skill_name string
---@return boolean
function Room:askForSkillInvoke(player, skill_name, data)
  local command = "AskForSkillInvoke"
  self:notifyMoveFocus(player, skill_name)
  local invoked = false
  local result = self:doRequest(player, command, skill_name)
  if result ~= "" then invoked = true end
  return invoked
end

---@param player ServerPlayer
---@param num integer
---@param reason "loseHp"|"damage"|"recover"|null
---@param skillName string
---@param damageStruct DamageStruct|null
---@return boolean
function Room:changeHp(player, num, reason, skillName, damageStruct)
  if num == 0 then
    return false
  end
  assert(reason == nil or table.contains({ "loseHp", "damage", "recover" }, reason))

  ---@type HpChangedData
  local data = {
    num = num,
    reason = reason,
    skillName = skillName,
  }

  if self.logic:trigger(fk.BeforeHpChanged, player, data) then
    return false
  end

  assert(not (data.reason == "recover" and data.num < 0))
  player.hp = math.min(player.hp + data.num, player.maxHp)

  self.logic:trigger(fk.HpChanged, player, data)

  if player.hp < 1 then
    ---@type DyingStruct
    local dyingStruct = {
      who = player.id,
      damage = damageStruct,
    }
    self:enterDying(dyingStruct)
  elseif player.dying then
    player.dying = false
  end

  return true
end

---@param player ServerPlayer
---@param num integer
---@param skillName string
---@return boolean
function Room:loseHp(player, num, skillName)
  if num == nil then
    num = 1
  elseif num < 1 then
    return false
  end

  ---@type HpLostData
  local data = {
    num = num,
    skillName = skillName,
  }
  if self.logic:trigger(fk.PreHpLost, player, data) or data.num < 1 then
    return false
  end

  if not self:changeHp(player, -num, "loseHp", skillName) then
    return false
  end

  self.logic:trigger(fk.HpLost, player, data)
  return true
end

---@param player ServerPlayer
---@param num integer
---@return boolean
function Room:changeMaxHp(player, num)
  if num == 0 then
    return false
  end

  player.maxHp = math.max(player.maxHp + num, 0)
  local diff = player.hp - player.maxHp
  if diff > 0 then
    if not self:changeHp(player, -diff) then
      player.hp = player.hp - diff
    end
  end

  if player.maxHp == 0 then
    self:killPlayer({ who = player.id })
  end

  self.logic:trigger(fk.MaxHpChanged, player, { num = num })
  return true
end

---@param damageStruct DamageStruct
---@return boolean
function Room:damage(damageStruct)
  if damageStruct.damage < 1 then
    return false
  end

  assert(type(damageStruct.to) == "number")

  local stages = {
    [fk.PreDamage] = damageStruct.from,
    [fk.DamageCaused] = damageStruct.from,
    [fk.DamageInflicted] = damageStruct.to,
  }

  for event, playerId in ipairs(stages) do
    local player = playerId and self:getPlayerById(playerId) or nil
    if self.logic:trigger(event, player, damageStruct) or damageStruct.damage < 1 then
      return false
    end

    assert(type(damageStruct.to) == "number")
  end

  assert(self:getPlayerById(damageStruct.to))
  local victim = self:getPlayerById(damageStruct.to)
  if not victim:isAlive() then
    return false
  end

  if not self:changeHp(victim, -damageStruct.damage, "damage", damageStruct.skillName, damageStruct) then
    return false
  end   

  stages = {
    [fk.Damage] = damageStruct.from,
    [fk.Damaged] = damageStruct.to,
    [fk.DamageFinished] = damageStruct.from,
  }

  for event, playerId in ipairs(stages) do
    local player = playerId and self:getPlayerById(playerId) or nil
    self.logic:trigger(event, player, damageStruct)
  end

  return true
end

---@param recoverStruct RecoverStruct
---@return boolean
function Room:recover(recoverStruct)
  if recoverStruct.num < 1 then
    return false
  end

  local who = self:getPlayerById(recoverStruct.who)
  if self.logic:trigger(fk.PreHpRecover, who, recoverStruct) or recoverStruct.num < 1 then
    return false
  end

  if not self:changeHp(who, recoverStruct.num, "recover", recoverStruct.skillName) then
    return false
  end

  self.logic:trigger(fk.HpRecover, who, recoverStruct)
  return true
end

---@param dyingStruct DyingStruct
function Room:enterDying(dyingStruct)
  local dyingPlayer = self:getPlayerById(dyingStruct.who)
  dyingPlayer.dying = true
  self.logic:trigger(fk.EnterDying, dyingPlayer, dyingStruct)

  if dyingPlayer.hp < 1 then
    local alivePlayers = self:getAlivePlayers()
    for _, player in ipairs(alivePlayers) do
      self.logic:trigger(fk.Dying, player, dyingStruct)
  
      if player.hp > 0 then
        break
      end
    end

    if dyingPlayer.hp < 1 then
      ---@type DeathStruct
      local deathData = {
        who = dyingPlayer.id,
        damage = dyingStruct.damage,
      }
      self:killPlayer(deathData)
    end
  end
  
  self.logic:trigger(fk.AfterDying, dyingPlayer, dyingStruct)
end

---@param deathStruct DeathStruct
function Room:killPlayer(deathStruct)
  print(self:getPlayerById(deathStruct.who).general .. " is dead")
  self:gameOver()
end

---@param room Room
---@param cardUseEvent CardUseStruct
---@param aimEventCollaborators table<string, AimStruct[]>
---@return boolean
local onAim = function(room, cardUseEvent, aimEventCollaborators)
  local eventStages = { fk.TargetSpecifying, fk.TargetConfirming, fk.TargetSpecified, fk.TargetConfirmed }
  for _, stage in ipairs(eventStages) do
    if not cardUseEvent.tos then
      return false
    end

    room:sortPlayersByAction(cardUseEvent.tos)
    local aimGroup = AimGroup:initAimGroup(TargetGroup:getRealTargets(cardUseEvent.tos))

    local collaboratorsIndex = {}
    local firstTarget = true
    repeat
      local toId = AimGroup:getUndoneOrDoneTargets(aimGroup)[1]
      ---@type AimStruct
      local aimStruct
      local initialEvent = false
      collaboratorsIndex[toId] = collaboratorsIndex[toId] or 0

      if not aimEventCollaborators[toId] or collaboratorsIndex[toId] >= #aimEventCollaborators[toId] then
        aimStruct = {
          from = cardUseEvent.from,
          cardId = cardUseEvent.cardId,
          to = toId,
          targetGroup = cardUseEvent.tos,
          nullifiedTargets = cardUseEvent.nullifiedTargets or {},
          tos = aimGroup,
          firstTarget = firstTarget,
          additionalDamage = cardUseEvent.addtionalDamage
        }

        collaboratorsIndex[toId] = 1
        initialEvent = true
      else
        aimStruct = aimEventCollaborators[toId][collaboratorsIndex[toId]]
        aimStruct.from = cardUseEvent.from
        aimStruct.cardId = cardUseEvent.cardId
        aimStruct.tos = aimGroup
        aimStruct.targetGroup = cardUseEvent.tos
        aimStruct.nullifiedTargets = cardUseEvent.nullifiedTargets or {}
        aimStruct.firstTarget = firstTarget
      end

      firstTarget = false

      if room.logic:trigger(stage, (stage == fk.TargetSpecifying or stage == fk.TargetSpecified) and room:getPlayerById(aimStruct.from) or room:getPlayerById(aimStruct.to), aimStruct) then
        return false
      end
      AimGroup:removeDeadTargets(room, aimStruct)

      local aimEventTargetGroup = aimStruct.targetGroup
      if aimEventTargetGroup then
        room:sortPlayersByAction(aimEventTargetGroup)
      end

      cardUseEvent.from = aimStruct.from
      cardUseEvent.tos = aimEventTargetGroup
      cardUseEvent.nullifiedTargets = aimStruct.nullifiedTargets
      
      if #AimGroup:getAllTargets(aimStruct.tos) == 0 then
        return false
      end

      local cancelledTargets = AimGroup:getCancelledTargets(aimStruct.tos)
      if #cancelledTargets > 0 then
        for _, target in ipairs(cancelledTargets) do
          aimEventCollaborators[target] = {}
          collaboratorsIndex[target] = 0
        end
      end
      aimStruct.tos[AimGroup.Cancelled] = {}

      aimEventCollaborators[toId] = aimEventCollaborators[toId] or {}
      if not room:getPlayerById(toId):isAlive() then
        if initialEvent then
          table.insert(aimEventCollaborators[toId], aimStruct)
        else
          aimEventCollaborators[toId][collaboratorsIndex[toId]] = aimStruct
        end
      end

      AimGroup:setTargetDone(aimStruct.tos, toId)
      aimGroup = aimStruct.tos
    until #AimGroup:getUndoneOrDoneTargets(aimGroup) == 0
  end

  return true
end

---@param cardUseEvent CardUseStruct
---@return boolean
function Room:useCard(cardUseEvent)
  self:moveCards({
    ids = { cardUseEvent.cardId },
    from = cardUseEvent.customFrom or cardUseEvent.from,
    toArea = Card.Processing,
    moveReason = fk.ReasonUse,
  })
  
  if Fk:getCardById(cardUseEvent.cardId).skill then
    Fk:getCardById(cardUseEvent.cardId).skill:onUse(self, cardUseEvent)
  end
  if self.logic:trigger(fk.PreCardUse, self:getPlayerById(cardUseEvent.from), cardUseEvent) then
    return false
  end

  if not cardUseEvent.extraUse then
    self:getPlayerById(cardUseEvent.from):addCardUseHistory(Fk:getCardById(cardUseEvent.cardId).trueName, 1)
  end

  if cardUseEvent.responseToEvent then
    cardUseEvent.responseToEvent.cardIdsResponded = cardUseEvent.responseToEvent.cardIdsResponded or {}
    table.insert(cardUseEvent.responseToEvent.cardIdsResponded, cardUseEvent.cardId)
  end

  for _, event in ipairs({ fk.AfterCardUseDeclared, fk.AfterCardTargetDeclared, fk.BeforeCardUseEffect, fk.CardUsing }) do
    -- TODO: need to complete the cards for response

    self.logic:trigger(event, self:getPlayerById(cardUseEvent.from), cardUseEvent)
    if event == fk.CardUsing then
      ---@type table<string, AimStruct>
      local aimEventCollaborators = {}
      if cardUseEvent.tos and not onAim(self, cardUseEvent, aimEventCollaborators) then
        break
      end

      if Fk:getCardById(cardUseEvent.cardId).type == Card.TypeEquip then
        if self:getCardArea(cardUseEvent.cardId) ~= Card.Processing then
          break
        end

        if self:getPlayerById(TargetGroup:getRealTargets(cardUseEvent.tos)[1]).dead then
          self.moveCards({
            ids = { cardUseEvent.cardId },
            toArea = Card.DiscardPile,
            moveReason = fk.ReasonPutIntoDiscardPile,
          })
        else
          local target = TargetGroup:getRealTargets(cardUseEvent.tos)[1]
          local existingEquipId = self:getPlayerById(target):getEquipment(Fk:getCardById(cardUseEvent.cardId).sub_type)
          if existingEquipId then
            self:moveCards(
              {
                ids = { existingEquipId },
                from = target,
                toArea = Card.DiscardPile,
                moveReason = fk.ReasonPutIntoDiscardPile,
              },
              {
                ids = { cardUseEvent.cardId },
                to = target,
                toArea = Card.PlayerEquip,
                moveReason = fk.ReasonUse,
              }
            )
          else
            self:moveCards({
              ids = { cardUseEvent.cardId },
              to = target,
              toArea = Card.PlayerEquip,
              moveReason = fk.ReasonUse,
            })
          end
        end

        break
      elseif Fk:getCardById(cardUseEvent.cardId).sub_type == Card.SubtypeDelayedTrick then
        if self:getCardArea(cardUseEvent.cardId) ~= Card.Processing then
          break
        end
        
        local target = TargetGroup:getRealTargets(cardUseEvent.tos)[1]
        if not self:getPlayerById(target).dead then
          local findSameCard = false
          for _, cardId in ipairs(self:getPlayerById(target):getCardIds(Player.Equip)) do
            if Fk:getCardById(cardId).trueName == Fk:getCardById(cardUseEvent.cardId) then
              findSameCard = true
            end
          end

          if not findSameCard then
            self:moveCards({
              ids = { cardUseEvent.cardId },
              to = target,
              toArea = Card.PlayerJudge,
              moveReason = fk.ReasonUse,
            })

            break
          end
        end

        self:moveCards({
          ids = { cardUseEvent.cardId },
          toArea = Card.DiscardPile,
          moveReason = fk.ReasonPutIntoDiscardPile,
        })

        break
      end

      if Fk:getCardById(cardUseEvent.cardId).skill then
        Fk:getCardById(cardUseEvent.cardId).skill:onEffect(self, cardUseEvent)
      end
    end
  end

  self.logic:trigger(fk.CardUseFinished, self:getPlayerById(cardUseEvent.from), cardUseEvent)
  if self:getCardArea(cardUseEvent.cardId) == Card.Processing then
    self:moveCards({
      ids = { cardUseEvent.cardId },
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPutIntoDiscardPile,
    })
  end
end

---@param player ServerPlayer
---@param skill_names string[] | string
---@param source_skill string | Skill | nil
function Room:handleAddLoseSkills(player, skill_names, source_skill)
  if type(skill_names) == "string" then
    skill_names = skill_names:split("|")
  end

  if #skill_names == 0 then return end
  local losts = {}  ---@type boolean[]
  local triggers = {} ---@type Skill[]
  for _, skill in ipairs(skill_names) do
    if string.sub(skill, 1, 1) == "-" then
      local actual_skill = string.sub(skill, 2, #skill)
      if player:hasSkill(actual_skill) then
        local lost_skills = player:loseSkill(actual_skill, source_skill)
        for _, s in ipairs(lost_skills) do
          self:doBroadcastNotify("LoseSkill", json.encode{
            player.id,
            s.name
          })
          -- TODO: send a log here
          table.insert(losts, true)
          table.insert(triggers, s)
        end
      end
    else
      local sk = Fk.skills[skill]
      if sk and not player:hasSkill(sk) then
        local got_skills = player:addSkill(sk)

        for _, s in ipairs(got_skills) do
          -- TODO: limit skill mark

          self:doBroadcastNotify("AddSkill", json.encode{
            player.id,
            s.name
          })
          -- TODO: send log
          table.insert(losts, false)
          table.insert(triggers, s)
        end
      end
    end
  end

  if #triggers > 0 then
    for i = 1, #triggers do
      local event = losts[i] and fk.EventLoseSkill or fk.EventAcquireSkill
      self.logic:trigger(event, player, triggers[i])
    end
  end
end

fk.room_callback["QuitRoom"] = function(jsonData)
  -- jsonData: [ int uid ]
  local data = json.decode(jsonData)
  local player = fk.ServerInstance:findPlayer(tonumber(data[1]))
  local room = player:getRoom()
  if not room:isLobby() then
    room:removePlayer(player)
  end
end

fk.room_callback["AddRobot"] = function(jsonData)
  -- jsonData: [ int uid ]
  local data = json.decode(jsonData)
  local player = fk.ServerInstance:findPlayer(tonumber(data[1]))
  local room = player:getRoom()
  
  if not room:isLobby() then
    room:addRobot(player)
  end
end

function CreateRoom(_room)
  RoomInstance = Room:new(_room)
end
