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
---@field owner_map table<integer, integer>
local Room = class("Room")

-- load classes used by the game
GameLogic = require "server.gamelogic"
ServerPlayer = require "server.serverplayer"

--[[--------------------------------------------------------------------
  Room stores all information for server side game room, such as player,
  cards, and other properties.
  It also have a lots of functions that make sure the room run properly.

  content of class Room:
  * contructor
  * getter/setters
  * Basic network functions, notify functions
  * Interactive methods
  * simple game actions, like judge, damage...
  * using cards
  * moving cards

  callbacks (not part of Room)
  see also:
    gamelogic.lua (for the game's main loop and trigger event)
    game_rule.lua (draw initial cards, proceed phase, etc.)
    aux_skills.lua (useful ActiveSkill for some interactive functions)
]]----------------------------------------------------------------------

------------------------------------------------------------------------
-- constructor
------------------------------------------------------------------------

---@param _room fk.Room
function Room:initialize(_room)
  self.room = _room

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
  self.owner_map = {}
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

------------------------------------------------------------------------
-- getters and setters
------------------------------------------------------------------------

---@param cardId integer
---@param cardArea CardArea
---@param integer owner
function Room:setCardArea(cardId, cardArea, owner)
  self.card_place[cardId] = cardArea
  self.owner_map[cardId] = owner
end

---@param cardId integer
---@return CardArea
function Room:getCardArea(cardId)
  return self.card_place[cardId] or Card.Unknown
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

---@param player ServerPlayer
---@param mark string
---@param value integer
function Room:setPlayerMark(player, mark, value)
  player:setMark(mark, value)
  self:doBroadcastNotify("SetPlayerMark", json.encode{
    player.id,
    mark,
    value
  })
end

function Room:addPlayerMark(player, mark, count)
  count = count or 1
  local num = player:getMark(mark)
  num = num or 0
  self:setPlayerMark(player, mark, math.max(num + count, 0))
end

function Room:removePlayerMark(player, mark, count)
  count = count or 1
  local num = player:getMark(mark)
  num = num or 0
  self:setPlayerMark(player, mark, math.max(num - count, 0))
end

------------------------------------------------------------------------
-- network functions, notify function
------------------------------------------------------------------------

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
function Room:doBroadcastRequest(command, players, jsonData)
  players = players or self.players
  self:notifyMoveFocus(players, command)
  for _, p in ipairs(players) do
    self:doRequest(p, command, jsonData or p.request_data, false)
  end

  local remainTime = self.timeout
  local currentTime = os.time()
  local elapsed = 0
  for _, p in ipairs(players) do
    elapsed = os.time() - currentTime
    p:waitForReply(remainTime - elapsed)
  end
end

---@param command string
---@param players ServerPlayer[]
function Room:doRaceRequest(command, players, jsonData)
  players = players or self.players
  -- self:notifyMoveFocus(players, command)
  for _, p in ipairs(players) do
    self:doRequest(p, command, jsonData or p.request_data, false)
  end

  local remainTime = self.timeout
  local currentTime = os.time()
  local elapsed = 0
  local winner
  local canceled_players = {}
  while true do
    elapsed = os.time() - currentTime
    if remainTime - elapsed <= 0 then
      return nil
    end
    for _, p in ipairs(players) do
      p:waitForReply(0)
      if p.reply_ready == true then
        winner = p
        break
      end

      if p.reply_cancel then
        table.insertIfNeed(canceled_players, p)
      end
    end
    if winner then
      self:doBroadcastNotify("CancelRequest", "")
      return winner
    end

    if #players == #canceled_players then
      return nil
    end
  end
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

---@param log LogMessage
function Room:sendLog(log)
  self:doBroadcastNotify("GameLog", json.encode(log))
end

------------------------------------------------------------------------
-- interactive functions
------------------------------------------------------------------------

---@param player ServerPlayer
---@param skill_name string
---@param prompt string
---@param cancelable boolean
---@param extra_data table
function Room:askForUseActiveSkill(player, skill_name, prompt, cancelable, extra_data)
  prompt = prompt or ""
  cancelable = cancelable or false
  extra_data = extra_data or {}
  local skill = Fk.skills[skill_name]
  if not (skill and skill:isInstanceOf(ActiveSkill)) then
    print("Attempt ask for use non-active skill: " .. skill_name)
    return false
  end

  local command = "AskForUseActiveSkill"
  self:notifyMoveFocus(player, skill_name)  -- for display skill name instead of command name
  local data = {skill_name, prompt, cancelable, json.encode(extra_data)}
  local result = self:doRequest(player, command, json.encode(data))

  if result == "" then
    return false
  end

  data = json.decode(result)
  local card = data.card
  local targets = data.targets
  local card_data = json.decode(card)
  local selected_cards = card_data.subcards
  skill:onEffect(room, {
    from = player.id,
    cards = selected_cards,
    tos = targets,
  })

  return true, {
    cards = selected_cards,
    targets = targets
  }
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

  local toDiscard = {}
  local data = {
    num = maxNum,
    min_num = minNum,
    include_equip = includeEquip,
    reason = skillName
  }
  local _, ret = self:askForUseActiveSkill(player, "discard_skill", "", true, data)
  if ret then
    toDiscard = ret.cards
  else
    local hands = player:getCardIds(Player.Hand)
    for i = 1, minNum do
      local randomId = hands[math.random(1, #hands)]
      table.insert(toDiscard, randomId)
      table.removeOne(hands, randomId)
    end
  end

  self:throwCard(toDiscard, skillName, player, player)
end

---@param player ServerPlayer
---@param targets ServerPlayer[]
---@param minNum integer
---@param maxNum integer
---@return integer[]
function Room:askForChoosePlayers(player, targets, minNum, maxNum, skillName)
  if minNum < 1 then
    return nil
  end

  local data = {
    targets = targets,
    num = maxNum,
    min_num = minNum,
    reason = skillName
  }
  local _, ret = self:askForUseActiveSkill(player, "choose_players_skill", "", true, data)
  if ret then
    return ret.targets
  else
    -- TODO: default
    return {}
  end
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
---@return CardUseStruct
function Room:askForUseCard(player, card_name, prompt, cancelable, extra_data)
  local command = "AskForUseCard"
  self:notifyMoveFocus(player, card_name)
  cancelable = cancelable or false
  extra_data = extra_data or {}
  prompt = prompt or "#AskForUseCard"

  local data = {card_name, prompt, cancelable, extra_data}
  local result = self:doRequest(player, command, json.encode(data))
  if result ~= "" then
    data = json.decode(result)
    local card = data.card
    local targets = data.targets
    if type(card) == "string" then
      -- TODO: ViewAsSkill
      return nil
    else
      local use = {}    ---@type CardUseStruct
      use.from = player.id
      use.tos = {}
      for _, target in ipairs(targets) do
        table.insert(use.tos, { target })
      end
      if #use.tos == 0 then
        use.tos = nil
      end
      use.cardId = card
      return use
    end
  end
  return nil
end

function Room:askForResponse(player, card_name, prompt, cancelable, extra_data)
  local command = "AskForResponseCard"
  self:notifyMoveFocus(player, card_name)
  cancelable = cancelable or false
  extra_data = extra_data or {}
  prompt = prompt or "#AskForResponseCard"

  local data = {card_name, prompt, cancelable, extra_data}
  local result = self:doRequest(player, command, json.encode(data))
  if result ~= "" then
    data = json.decode(result)
    local card = data.card
    local targets = data.targets
    if type(card) == "string" then
      -- TODO: ViewAsSkill
      return nil
    else
      return card
    end
  end
  return nil
end

function Room:askForNullification(players, card_name, prompt, cancelable, extra_data)
  if #players == 0 then
    return nil
  end

  local command = "AskForUseCard"
  card_name = card_name or "nullification"
  cancelable = cancelable or false
  extra_data = extra_data or {}
  prompt = prompt or "#AskForUseCard"

  self:notifyMoveFocus(self.players, card_name)
  self:doBroadcastNotify("WaitForNullification", "")

  local data = {card_name, prompt, cancelable, extra_data}
  local winner = self:doRaceRequest(command, players, json.encode(data))
  if winner then
    local result = winner.client_reply
    data = json.decode(result)
    local card = data.card
    local targets = data.targets
    if type(card) == "string" then
      -- TODO: ViewAsSkill
      return nil
    else
      local use = {}    ---@type CardUseStruct
      use.from = winner.id
      use.tos = {}
      for _, target in ipairs(targets) do
        table.insert(use.tos, { target })
      end
      if #use.tos == 0 then
        use.tos = nil
      end
      use.cardId = card
      return use
    end
  end
  return nil
end

------------------------------------------------------------------------
-- use card logic, and wrappers
------------------------------------------------------------------------

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

    room:sortPlayersByAction(cardUseEvent.tos)
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
    if not cardUseEvent.toCardId and #TargetGroup:getRealTargets(cardUseEvent.tos) == 0 then
      break
    end

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
        ---@type CardEffectEvent
        local cardEffectEvent = {
          from = cardUseEvent.from,
          tos = cardUseEvent.tos,
          cardId = cardUseEvent.cardId,
          toCardId = cardUseEvent.toCardId,
          responseToEvent = cardUseEvent.responseToEvent,
          nullifiedTargets = cardUseEvent.nullifiedTargets,
          disresponsiveList = cardUseEvent.disresponsiveList,
          unoffsetableList = cardUseEvent.unoffsetableList,
          addtionalDamage = cardUseEvent.addtionalDamage,
          cardIdsResponded = cardUseEvent.nullifiedTargets,
        }

        if cardUseEvent.toCardId ~= nil then
          self:doCardEffect(cardEffectEvent)
        else
          local collaboratorsIndex = {}
          for _, toId in ipairs(TargetGroup:getRealTargets(cardUseEvent.tos)) do
            if not table.contains(cardUseEvent.nullifiedTargets, toId) and self:getPlayerById(toId):isAlive() then
              if aimEventCollaborators[toId] then
                cardEffectEvent.to = toId
                collaboratorsIndex[toId] = collaboratorsIndex[toId] or 1
                local curAimEvent = aimEventCollaborators[toId][collaboratorsIndex[toId]]

                cardEffectEvent.addtionalDamage = curAimEvent.additionalDamage

                if curAimEvent.disresponsiveList then
                  for _, disresponsivePlayer in ipairs(curAimEvent.disresponsiveList) do
                    if not table.contains(cardEffectEvent.disresponsiveList, disresponsivePlayer) then
                      table.insert(cardEffectEvent.disresponsiveList, disresponsivePlayer)
                    end
                  end
                end

                if curAimEvent.unoffsetableList then
                  for _, unoffsetablePlayer in ipairs(curAimEvent.unoffsetableList) do
                    if not table.contains(cardEffectEvent.unoffsetablePlayer, unoffsetablePlayer) then
                      table.insert(cardEffectEvent.unoffsetablePlayer, unoffsetablePlayer)
                    end
                  end
                end

                cardEffectEvent.disresponsive = curAimEvent.disresponsive
                cardEffectEvent.unoffsetable = curAimEvent.unoffsetable

                collaboratorsIndex[toId] = collaboratorsIndex[toId] + 1

                self:doCardEffect(cardEffectEvent)
              end
            end
          end
        end
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

---@param cardEffectEvent CardEffectEvent
function Room:doCardEffect(cardEffectEvent)
  for _, event in ipairs({ fk.PreCardEffect, fk.BeforeCardEffect, fk.CardEffecting, fk.CardEffectFinished }) do
    if cardEffectEvent.isCancellOut then
      self.logic:trigger(fk.CardEffectCancelledOut, self:getPlayerById(cardEffectEvent.from), cardEffectEvent)
      break
    end
    
    if not cardEffectEvent.toCardId and (not (self:getPlayerById(cardEffectEvent.to):isAlive() and cardEffectEvent.to) or #self:deadPlayerFilter(TargetGroup:getRealTargets(cardEffectEvent.tos)) == 0) then
      break
    end

    if table.contains((cardEffectEvent.nullifiedTargets or {}), cardEffectEvent.to) then
      break
    end

    if self.logic:trigger(event, self:getPlayerById(cardEffectEvent.from), cardEffectEvent) then
      return
    end

    if event == fk.PreCardEffect then
      if Fk:getCardById(cardEffectEvent.cardId).name == 'slash' and
        not (
          cardEffectEvent.disresponsive or
          cardEffectEvent.unoffsetable or
          table.contains(cardEffectEvent.disresponsiveList or {}, cardEffectEvent.to) or
          table.contains(cardEffectEvent.unoffsetableList or {}, cardEffectEvent.to)
        ) then
        local to = self:getPlayerById(cardEffectEvent.to)
        local use = self:askForUseCard(to, "jink")
        if use then
          use.toCardId = cardEffectEvent.cardId
          use.responseToEvent = cardEffectEvent
          self:useCard(use)
        end
      elseif Fk:getCardById(cardEffectEvent.cardId).type == Card.TypeTrick then
        local players = {}
        for _, p in ipairs(self.players) do
          local cards = p.player_cards[Player.Hand]
          for _, cid in ipairs(cards) do
            if Fk:getCardById(cid).name == "nullification" then
              table.insert(players, p)
              break
            end
          end
        end

        local use = self:askForNullification(players)
        if use then
          use.toCardId = cardEffectEvent.cardId
          use.responseToEvent = cardEffectEvent
          self:useCard(use)
        end
      end
    end

    if event == fk.CardEffecting then
      local cardEffecting = Fk:getCardById(cardEffectEvent.cardId)
      if cardEffecting.skill then
        cardEffecting.skill:onEffect(self, cardEffectEvent)
      end
    end
  end
end

------------------------------------------------------------------------
-- move cards, and wrappers
------------------------------------------------------------------------

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
        self:setCardArea(info.cardId, data.toArea, data.to)
      end
    end
  end

  self.logic:trigger(fk.AfterCardsMove, nil, cardsMoveStructs)
  return true
end

---@param player integer
---@param cid integer
---@param unhide boolean
---@param reason CardMoveReason
function Room:obtainCard(player, cid, unhide, reason)
  self:moveCards({
    ids = {cid},
    from = self.owner_map[cid],
    to = player,
    toArea = Card.PlayerHand,
    moveReason = reason or fk.ReasonJustMove,
    proposer = player,
    moveVisible = unhide or false,
  })
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

---@param card Card | Card[]
---@param to_place integer
---@param target ServerPlayer
---@param reason integer
---@param skill_name string
---@param special_name string
function Room:moveCardTo(card, to_place, target, reason, skill_name, special_name)
  reason = reason or fk.ReasonJustMove
  skill_name = skill_name or ""
  special_name = special_name or ""
  local ids = {}
  if card[1] ~= nil then
    for i, cd in ipairs(card) do
      ids[i] = cd.id
    end
  else
    ids[1] = card.id
  end

  local to
  if table.contains(
    {Card.PlayerEquip, Card.PlayerHand,
     Card.PlayerJudge, Card.PlayerSpecial}, to_place) then
    to = target.id
  end

  self.moveCards{
    ids = ids,
    from = self.owner_map[ids[1]],
    to = to,
    toArea = to_place,
    moveReason = reason,
    skillName = skill_name,
    specialName = special_name
  }
end

------------------------------------------------------------------------
-- some easier actions
------------------------------------------------------------------------

-- actions related to hp

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
  self:broadcastProperty(player, "hp")

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
  self:broadcastProperty(player, "maxHp")
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
  self:broadcastProperty(dyingPlayer, "dying")
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
  local victim = self:getPlayerById(deathStruct.who)
  victim.dead = true
  table.removeOne(self.alive_players, victim)
  
  local logic = self.logic
  logic:trigger(fk.BeforeGameOverJudge, victim, deathStruct)

  -- TODO: send log
  self:broadcastProperty(victim, "role")
  self:broadcastProperty(victim, "dead")

  logic:trigger(fk.GameOverJudge, victim, deathStruct)
  logic:trigger(fk.Death, victim, deathStruct)
  logic:trigger(fk.BuryVictim, victim, deathStruct)
end

-- lose/acquire skill actions

---@param player ServerPlayer
---@param skill_names string[] | string
---@param source_skill string | Skill | nil
function Room:handleAddLoseSkills(player, skill_names, source_skill, sendlog)
  if type(skill_names) == "string" then
    skill_names = skill_names:split("|")
  end

  if sendlog == nil then sendlog = true end

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

          if sendlog then
            self:sendLog{
              type = "#LoseSkill",
              from = player.id,
              arg = s.name
            }
          end

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

          if sendlog then
            self:sendLog{
              type = "#AcquireSkill",
              from = player.id,
              arg = s.name
            }
          end

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

-- judge

---@param data JudgeData
---@return Card
function Room:judge(data)
  local who = data.who
  self.logic:trigger(fk.StartJudge, who, data)
  data.card = Fk:getCardById(self:getNCards(1)[1])
  self:sendLog{
    type = "#InitialJudge",
    from = who.id,
    card = {data.card},
  }
  self:moveCardTo(data.card, Card.Processing, nil, fk.ReasonPrey)

  self.logic:trigger(fk.AskForRetrial, who, data)
  self.logic:trigger(fk.FinishRetrial, who, data)
  self:sendLog{
    type = "#JudgeResult",
    from = who.id,
    card = {data.card},
  }

  self.logic:trigger(fk.FinishJudge, who, data)
  if self:getCardArea(data.card.id) == Card.Processing then
    self:moveCardTo(data.card, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile)
  end
end

---@param card_ids integer[]
---@param skillName string
---@param who ServerPlayer
---@param thrower ServerPlayer
function Room:throwCard(card_ids, skillName, who, thrower)
  if type(card_ids) == "number" then
    card_ids = {card_ids}
  end
  skillName = skillName or ""
  thrower = thrower or who
  self:moveCards({
    ids = card_ids,
    from = who.id,
    toArea = Card.DiscardPile,
    moveReason = fk.ReasonDiscard,
    proposer = thrower.id,
    skillName = skillName
  })
end

-- other helpers

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
    self:setCardArea(id, Card.DrawPile, nil)
  end
  self.discard_pile = {}
  table.shuffle(self.draw_pile)
end

function Room:gameOver(winner)
  self.game_finished = true
  fk.qInfo(string.format("winner is %s", winner))
  -- dosomething
  self.room:gameOver()
end

function CreateRoom(_room)
  RoomInstance = Room:new(_room)
end
