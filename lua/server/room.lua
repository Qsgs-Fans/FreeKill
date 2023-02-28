---@class Room : Object
---@field room fk.Room
---@field players ServerPlayer[]
---@field alive_players ServerPlayer[]
---@field observers fk.ServerPlayer[]
---@field current ServerPlayer
---@field game_started boolean
---@field game_finished boolean
---@field timeout integer
---@field tag table<string, any>
---@field draw_pile integer[]
---@field discard_pile integer[]
---@field processing_area integer[]
---@field void integer[]
---@field card_place table<integer, CardArea>
---@field owner_map table<integer, integer>
---@field status_skills Skill[]
local Room = class("Room")

-- load classes used by the game
GameEvent = require "server.gameevent"
dofile "lua/server/events/init.lua"
GameLogic = require "server.gamelogic"
ServerPlayer = require "server.serverplayer"

---@type Player
Self = nil -- `Self' is client-only, but we need it in AI
dofile "lua/server/ai/init.lua"

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
    local main_co = coroutine.create(function()
      self:run()
    end)
    local request_co = coroutine.create(function(rest)
      self:requestLoop(rest)
    end)
    local ret, err_msg = true, true
    while not self.game_finished do
      ret, _, err_msg = coroutine.resume(main_co, err_msg)

      -- handle error
      if ret == false then
        fk.qCritical(err_msg)
        print(debug.traceback(main_co))
        break
      end

      -- If ret == true, then err_msg is the millisecond left

      ret, err_msg = coroutine.resume(request_co, err_msg)
      if ret == false then
        fk.qCritical(err_msg)
        print(debug.traceback(request_co))
        break
      end

      -- If ret == true, then when err_msg is true, that means no request
    end
  end

  self.players = {}
  self.alive_players = {}
  self.observers = {}
  self.current = nil
  self.game_started = false
  self.game_finished = false
  self.timeout = _room:getTimeout()
  self.tag = {}
  self.draw_pile = {}
  self.discard_pile = {}
  self.processing_area = {}
  self.void = {}
  self.card_place = {}
  self.owner_map = {}
  self.status_skills = {}
  for class, skills in pairs(Fk.global_status_skill) do
    self.status_skills[class] = {table.unpack(skills)}
  end
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

---@param cardId integer | card
---@return CardArea
function Room:getCardArea(cardId)
  if type(cardId) ~= "number" then
    assert(cardId and cardId:isInstanceOf(Card))
    cardId = cardId:getEffectiveId()
  end
  return self.card_place[cardId] or Card.Unknown
end

---@param cardId integer | card
---@return ServerPlayer
function Room:getCardOwner(cardId)
  if type(cardId) ~= "number" then
    assert(cardId and cardId:isInstanceOf(Card))
    cardId = cardId:getEffectiveId()
  end
  return self.owner_map[cardId] and self:getPlayerById(self.owner_map[cardId]) or nil
end

---@param id integer
---@return ServerPlayer
function Room:getPlayerById(id)
  if not id then return nil end
  assert(type(id) == "number")

  for _, p in ipairs(self.players) do
    if p.id == id then
      return p
    end
  end

  return nil
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
function Room:getAllPlayers(sortBySeat)
  if not self.game_started then
    return { table.unpack(self.players) }
  end
  if sortBySeat == nil or sortBySeat then
    local current = self.current
    local temp = current.next
    local ret = {current}
    while temp ~= current do
      table.insert(ret, temp)
      temp = temp.next
    end

    return ret
  else
    return { table.unpack(self.players) }
  end
end

---@param sortBySeat boolean
---@return ServerPlayer[]
function Room:getAlivePlayers(sortBySeat)
  if sortBySeat == nil or sortBySeat then
    local current = self.current
    local temp = current.next

    -- did not arrange seat, use default
    if temp == nil then
      return { table.unpack(self.players) }
    end
    local ret = {current}
    while temp ~= current do
      if not temp.dead then
        table.insert(ret, temp)
      end
      temp = temp.next
    end

    return ret
  else
    return { table.unpack(self.alive_players) }
  end
end

---@param player ServerPlayer
---@param sortBySeat boolean
---@param include_dead boolean
---@return ServerPlayer[]
function Room:getOtherPlayers(player, sortBySeat, include_dead)
  if sortBySeat == nil then
    sortBySeat = true
  end

  local players = include_dead and self:getAllPlayers(sortBySeat) or self:getAlivePlayers(sortBySeat)
  for _, p in ipairs(players) do
    if p.id == player.id then
      table.removeOne(players, player)
      break
    end
  end

  return players
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
  for _, p in ipairs(players) do
    p:doNotify(command, jsonData)
  end
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

-- main loop for the request handling coroutine
function Room:requestLoop(rest_time)
  local function tellRoomToObserver(player)
    local observee = self.players[1]
    player:doNotify("Setup", json.encode{
      observee.id,
      player:getScreenName(),
      player:getAvatar(),
    })
    player:doNotify("EnterRoom", json.encode{
      #self.players, self.timeout,
      -- FIXME: use real room settings here
      { enableFreeAssign = false }
    })

    -- send player data
    for _, p in ipairs(self:getOtherPlayers(observee, true, true)) do
      player:doNotify("AddPlayer", json.encode{
        p.id,
        p.serverplayer:getScreenName(),
        p.serverplayer:getAvatar(),
      })
    end

    local player_circle = {}
    for i = 1, #self.players do
      table.insert(player_circle, self.players[i].id)
    end
    player:doNotify("ArrangeSeats", json.encode(player_circle))

    for _, p in ipairs(self.players) do
      self:notifyProperty(player, p, "general")
      p:marshal(player)
    end

    -- TODO: tell drawPile
    table.insert(self.observers, {observee.id, player})
  end

  local function addObserver(id)
    local all_observers = self.room:getObservers()
    for _, p in fk.qlist(all_observers) do
      if p:getId() == id then
        tellRoomToObserver(p)
        self:doBroadcastNotify("AddObserver", json.encode{
          p:getId(),
          p:getScreenName(),
          p:getAvatar()
        })
        break
      end
    end
  end

  local function removeObserver(id)
    for _, t in ipairs(self.observers) do
      local __, p = table.unpack(t)
      if p:getId() == id then
        table.removeOne(self.observers, t)
        self:doBroadcastNotify("RemoveObserver", json.encode{
          p:getId(),
        })
        break
      end
    end
  end

  while true do
    local ret = false
    local request = self.room:fetchRequest()
    if request ~= "" then
      ret = true
      local id, command = table.unpack(request:split(","))
      id = tonumber(id)
      if command == "reconnect" then
        self:getPlayerById(id):reconnect()
      elseif command == "observe" then
        addObserver(id)
      elseif command == "leave" then
        removeObserver(id)
      end
    elseif rest_time > 10 then
      -- let current thread sleep 10ms
      -- otherwise CPU usage will be 100% (infinite yield <-> resume loop)
      fk.QThread_msleep(10)
    end
    coroutine.yield(ret)
  end
end

-- delay function, should only be used in main coroutine
---@param ms integer @ millisecond to be delayed
function Room:delay(ms)
  local start = os.getms()
  while true do
    local rest = ms - (os.getms() - start) / 1000
    if rest <= 0 then
      break
    end
    coroutine.yield("__handleRequest", rest)
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

      local function infosContainArea(info, area)
        for _, i in ipairs(info) do
          if i.fromArea == area then
            return true
          end
        end
        return false
      end

      -- forceVisible make the move visible
      -- FIXME: move.moveInfo is an array, fix this
      move.moveVisible = move.moveVisible or (forceVisible)
        -- if move is relevant to player, it should be open
        or ((move.from == p.id) or (move.to == p.id))
        -- cards move from/to equip/judge/discard/processing should be open
        or infosContainArea(move.moveInfo, Card.PlayerEquip)
        or move.toArea == Card.PlayerEquip
        or infosContainArea(move.moveInfo, Card.PlayerJudge)
        or move.toArea == Card.PlayerJudge
        or infosContainArea(move.moveInfo, Card.DiscardPile)
        or move.toArea == Card.DiscardPile
        or infosContainArea(move.moveInfo, Card.Processing)
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

function Room:doAnimate(type, data, players)
  players = players or self.players
  data.type = type
  self:doBroadcastNotify("Animate", json.encode(data), players)
end

function Room:setEmotion(player, name)
  self:doAnimate("Emotion", {
    player = player.id,
    emotion = name
  })
end

function Room:setCardEmotion(cid, name)
  self:doAnimate("Emotion", {
    player = cid,
    emotion = name,
    is_card = true,
  })
end

function Room:doSuperLightBox(path, extra_data)
  path = path or "RoomElement/SuperLightBox.qml"
  self:doAnimate("SuperLightBox", {
    path = path,
    data = extra_data,
  })
end

function Room:sendLogEvent(type, data, players)
  players = players or self.players
  data.type = type
  self:doBroadcastNotify("LogEvent", json.encode(data), players)
end

---@param skill_name string
---@param index integer
function Room:broadcastSkillInvoke(skill_name, index)
  index = index or -1
  self:sendLogEvent("PlaySkillSound", {
    name = skill_name,
    i = index
  })
end

---@param skill_name string
---@param index integer
function Room:broadcastPlaySound(path)
  self:sendLogEvent("PlaySound", {
    name = path,
  })
end

---@param player ServerPlayer
---@param skill_name string
---@param skill_type string
function Room:notifySkillInvoked(player, skill_name, skill_type)
  if not skill_type then
    local skill = Fk.skills[skill_name]
    if not skill then skill_type = "" end
    skill_type = skill.anim_type
  end
  self:sendLog{
    type = "#InvokeSkill",
    from = player.id,
    arg = skill_name,
  }

  self:doAnimate("InvokeSkill", {
    name = skill_name,
    player = player.id,
    skill_type = skill_type,
  })
end

---@param source integer
---@param targets integer[]
function Room:doIndicate(source, targets)
  local target_group = {}
  for _, id in ipairs(targets) do
    table.insert(target_group, { id })
  end
  self:doAnimate("Indicate", {
    from = source,
    to = target_group,
  })
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
  self:notifyMoveFocus(player, extra_data.skillName or skill_name)  -- for display skill name instead of command name
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
  self:doIndicate(player.id, targets)
  skill:onUse(self, {
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
function Room:askForDiscard(player, minNum, maxNum, includeEquip, skillName, cancelable)
  if minNum < 1 then
    return nil
  end
  cancelable = cancelable or false

  local toDiscard = {}
  local data = {
    num = maxNum,
    min_num = minNum,
    include_equip = includeEquip,
    reason = skillName
  }
  local prompt = "#AskForDiscard:::" .. maxNum .. ":" .. minNum
  local _, ret = self:askForUseActiveSkill(player, "discard_skill", prompt, cancelable, data)
  if ret then
    toDiscard = ret.cards
  else
    if cancelable then return {} end
    local hands = player:getCardIds(Player.Hand)
    if includeEquip then
      table.insertTable(hands, player:getCardIds(Player.Equip))
    end
    for i = 1, minNum do
      local randomId = hands[math.random(1, #hands)]
      table.insert(toDiscard, randomId)
      table.removeOne(hands, randomId)
    end
  end

  self:throwCard(toDiscard, skillName, player, player)
  return toDiscard
end

---@param player ServerPlayer
---@param targets integer[]
---@param minNum integer
---@param maxNum integer
---@param prompt string
---@return integer[]
function Room:askForChoosePlayers(player, targets, minNum, maxNum, prompt, skillName)
  if maxNum < 1 then
    return {}
  end

  local data = {
    targets = targets,
    num = maxNum,
    min_num = minNum,
    pattern = "",
    skillName = skillName
  }
  local _, ret = self:askForUseActiveSkill(player, "choose_players_skill", prompt or "", true, data)
  if ret then
    return ret.targets
  else
    -- TODO: default
    return {}
  end
end

---@param player ServerPlayer
---@param targets integer[]
---@param minNum integer
---@param maxNum integer
---@param pattern string
---@param prompt string
---@return integer[], integer
function Room:askForChooseCardAndPlayers(player, targets, minNum, maxNum, pattern, prompt, skillName)
  if maxNum < 1 then
    return {}
  end

  local data = {
    targets = targets,
    num = maxNum,
    min_num = minNum,
    pattern = pattern or ".",
    skillName = skillName
  }
  local _, ret = self:askForUseActiveSkill(player, "choose_players_skill", prompt or "", true, data)
  if ret then
    return ret.targets, ret.cards[1]
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
    result = -1
  else
    result = tonumber(result)
  end

  if result == -1 then
    local areas = {}
    if string.find(flag, "h") then table.insert(areas, Player.Hand) end
    if string.find(flag, "e") then table.insert(areas, Player.Equip) end
    if string.find(flag, "j") then table.insert(areas, Player.Judge) end
    local handcards = target:getCardIds(areas)
    if #handcards == 0 then return end
    result = handcards[math.random(1, #handcards)]
  end

  return result
end

---@param player ServerPlayer
---@param choices string[]
---@param skill_name string
function Room:askForChoice(player, choices, skill_name, prompt, data)
  if #choices == 1 then return choices[1] end
  local command = "AskForChoice"
  prompt = prompt or ""
  self:notifyMoveFocus(player, skill_name)
  local result = self:doRequest(player, command, json.encode{
    choices, skill_name, prompt
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

-- TODO: guanxing type
function Room:askForGuanxing(player, cards)
  if #cards == 1 then
    table.insert(self.draw_pile, 1, cards[1])
    return
  end
  local command = "AskForGuanxing"
  self:notifyMoveFocus(player, command)
  local data = {
    cards = cards,
  }

  local result = self:doRequest(player, command, json.encode(data))
  local top, bottom
  if result ~= "" then
    local d = json.decode(result)
    top = d[1]
    bottom = d[2]
  else
    top = cards
    bottom = {}
  end

  for i = #top, 1, -1 do
    table.insert(self.draw_pile, 1, top[i])
  end
  for _, id in ipairs(bottom) do
    table.insert(self.draw_pile, id)
  end

  self:sendLog{
    type = "#GuanxingResult",
    from = player.id,
    arg = #top,
    arg2 = #bottom,
  }
end

---@param player ServerPlayer
---@param data string
---@return CardUseStruct
function Room:handleUseCardReply(player, data)
  data = json.decode(data)
  local card = data.card
  local targets = data.targets
  if type(card) == "string" then
    local card_data = json.decode(card)
    local skill = Fk.skills[card_data.skill]
    local selected_cards = card_data.subcards
    if skill:isInstanceOf(ActiveSkill) then
      self:useSkill(player, skill, function()
        self:doIndicate(player.id, targets)
        skill:onUse(self, {
          from = player.id,
          cards = selected_cards,
          tos = targets,
        })
      end)
      return nil
    elseif skill:isInstanceOf(ViewAsSkill) then
      local c = skill:viewAs(selected_cards)
      if c then
        self:useSkill(player, skill)
        local use = {}    ---@type CardUseStruct
        use.from = player.id
        use.tos = {}
        for _, target in ipairs(targets) do
          table.insert(use.tos, { target })
        end
        if #use.tos == 0 then
          use.tos = nil
        end
        use.card = c
        return use
      end
    end
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
    use.card = Fk:getCardById(card)
    return use
  end
end

-- available extra_data:
-- * must_targets: integer[]
---@param player ServerPlayer
---@param card_name string
---@param pattern string
---@param prompt string
---@return CardUseStruct
function Room:askForUseCard(player, card_name, pattern, prompt, cancelable, extra_data)
  local command = "AskForUseCard"
  self:notifyMoveFocus(player, card_name)
  cancelable = cancelable or false
  extra_data = extra_data or {}
  pattern = pattern or card_name
  prompt = prompt or ""

  local data = {card_name, pattern, prompt, cancelable, extra_data}
  local result = self:doRequest(player, command, json.encode(data))
  if result ~= "" then
    return self:handleUseCardReply(player, result)
  end
  return nil
end

---@param player ServerPlayer
---@param card_name string
---@param pattern string
---@param prompt string
---@param cancelable string
function Room:askForResponse(player, card_name, pattern, prompt, cancelable, extra_data)
  local command = "AskForResponseCard"
  self:notifyMoveFocus(player, card_name)
  cancelable = cancelable or false
  extra_data = extra_data or {}
  pattern = pattern or card_name
  prompt = prompt or ""

  local data = {card_name, pattern, prompt, cancelable, extra_data}
  local result = self:doRequest(player, command, json.encode(data))
  if result ~= "" then
    local use = self:handleUseCardReply(player, result)
    if use then
      return use.card
    end
  end
  return nil
end

function Room:askForNullification(players, card_name, pattern, prompt, cancelable, extra_data)
  if #players == 0 then
    return nil
  end

  local command = "AskForUseCard"
  card_name = card_name or "nullification"
  cancelable = cancelable or false
  extra_data = extra_data or {}
  prompt = prompt or ""
  pattern = pattern or card_name

  self:notifyMoveFocus(self.alive_players, card_name)
  self:doBroadcastNotify("WaitForNullification", "")

  local data = {card_name, pattern, prompt, cancelable, extra_data}
  local winner = self:doRaceRequest(command, players, json.encode(data))
  if winner then
    local result = winner.client_reply
    return self:handleUseCardReply(winner, result)
  end
  return nil
end

-- Show a qml dialog and return qml's ClientInstance.replyToServer
-- Do anything you like through this function

---@param player ServerPlayer
---@param focustxt string
---@param qmlPath string
---@param extra_data any
---@return string
function Room:askForCustomDialog(player, focustxt, qmlPath, extra_data)
  local command = "CustomDialog"
  self:notifyMoveFocus(player, focustxt)
  return self:doRequest(player, command, json.encode{
    path = qmlPath,
    data = extra_data,
  })
end

------------------------------------------------------------------------
-- use card logic, and wrappers
------------------------------------------------------------------------

local function execGameEvent(type, ...)
  local event = GameEvent:new(type, ...)
  local _, ret = event:exec()
  return ret
end

local playCardEmotionAndSound = function(room, player, card)
  if card.type ~= Card.TypeEquip then
    room:setEmotion(player, "./packages/" ..
      card.package.extensionName .. "/image/anim/" .. card.name)
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
          card = cardUseEvent.card,
          to = toId,
          targetGroup = cardUseEvent.tos,
          nullifiedTargets = cardUseEvent.nullifiedTargets or {},
          tos = aimGroup,
          firstTarget = firstTarget,
          additionalDamage = cardUseEvent.addtionalDamage
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
    goto clean
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

::clean::
  local leftRealCardIds = self:getSubcardsByRule(cardUseEvent.card, { Card.Processing })
  if #leftRealCardIds > 0 then
    self:moveCards({
      ids = leftRealCardIds,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPutIntoDiscardPile,
    })
  end
end

---@param cardUseEvent CardUseStruct
function Room:doCardUseEffect(cardUseEvent)
  ---@type table<string, AimStruct>
  local aimEventCollaborators = {}
  if cardUseEvent.tos and not onAim(self, cardUseEvent, aimEventCollaborators) then
    return
  end

  local realCardIds = self:getSubcardsByRule(cardUseEvent.card, { Card.Processing })

  -- If using Equip or Delayed trick, move them to the area and return
  if cardUseEvent.card.type == Card.TypeEquip then
    if #realCardIds == 0 then
      return
    end

    if self:getPlayerById(TargetGroup:getRealTargets(cardUseEvent.tos)[1]).dead then
      self.moveCards({
        ids = realCardIds,
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonPutIntoDiscardPile,
      })
    else
      local target = TargetGroup:getRealTargets(cardUseEvent.tos)[1]
      local existingEquipId = self:getPlayerById(target):getEquipment(cardUseEvent.card.sub_type)
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
    if not self:getPlayerById(target).dead then
      local findSameCard = false
      for _, cardId in ipairs(self:getPlayerById(target):getCardIds(Player.Judge)) do
        if Fk:getCardById(cardId).trueName == cardUseEvent.card.trueName then
          findSameCard = true
        end
      end

      if not findSameCard then
        if cardUseEvent.card:isVirtual() then
          self:getPlayerById(target):addVirtualEquip(cardUseEvent.card)
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

    self:moveCards({
      ids = realCardIds,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPutIntoDiscardPile,
    })

    return
  end

  if not cardUseEvent.card.skill then
    return
  end

  ---@type CardEffectEvent
  local cardEffectEvent = {
    from = cardUseEvent.from,
    tos = cardUseEvent.tos,
    card = cardUseEvent.card,
    toCard = cardUseEvent.toCard,
    responseToEvent = cardUseEvent.responseToEvent,
    nullifiedTargets = cardUseEvent.nullifiedTargets,
    disresponsiveList = cardUseEvent.disresponsiveList,
    unoffsetableList = cardUseEvent.unoffsetableList,
    addtionalDamage = cardUseEvent.addtionalDamage,
    cardIdsResponded = cardUseEvent.nullifiedTargets,
  }

  -- If using card to other card (like jink or nullification), simply effect and return
  if cardUseEvent.toCard ~= nil then
    self:doCardEffect(cardEffectEvent)
    return
  end

  -- Else: do effect to all targets
  local collaboratorsIndex = {}
  for _, toId in ipairs(TargetGroup:getRealTargets(cardUseEvent.tos)) do
    if not table.contains(cardUseEvent.nullifiedTargets, toId) and self:getPlayerById(toId):isAlive() then
      if aimEventCollaborators[toId] then
        cardEffectEvent.to = toId
        collaboratorsIndex[toId] = collaboratorsIndex[toId] or 1
        local curAimEvent = aimEventCollaborators[toId][collaboratorsIndex[toId]]

        cardEffectEvent.subTargets = curAimEvent.subTargets
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

        self:doCardEffect(table.simpleClone(cardEffectEvent))
      end
    end
  end
end

---@param cardEffectEvent CardEffectEvent
function Room:doCardEffect(cardEffectEvent)
  for _, event in ipairs({ fk.PreCardEffect, fk.BeforeCardEffect, fk.CardEffecting, fk.CardEffectFinished }) do
    if cardEffectEvent.isCancellOut then
      if cardEffectEvent.from then
        self.logic:trigger(fk.CardEffectCancelledOut, self:getPlayerById(cardEffectEvent.from), cardEffectEvent)
      end
      break
    end

    if not cardEffectEvent.toCard and (not (self:getPlayerById(cardEffectEvent.to):isAlive() and cardEffectEvent.to) or #self:deadPlayerFilter(TargetGroup:getRealTargets(cardEffectEvent.tos)) == 0) then
      break
    end

    if table.contains((cardEffectEvent.nullifiedTargets or {}), cardEffectEvent.to) then
      break
    end

    if cardEffectEvent.from and self.logic:trigger(event, self:getPlayerById(cardEffectEvent.from), cardEffectEvent) then
      return
    end

    if event == fk.PreCardEffect then
      if cardEffectEvent.card.skill:aboutToEffect(self, cardEffectEvent) then return end
      if cardEffectEvent.card.name == 'slash' and
        not (
          cardEffectEvent.disresponsive or
          cardEffectEvent.unoffsetable or
          table.contains(cardEffectEvent.disresponsiveList or {}, cardEffectEvent.to) or
          table.contains(cardEffectEvent.unoffsetableList or {}, cardEffectEvent.to)
        ) then
        local to = self:getPlayerById(cardEffectEvent.to)
        local prompt = ""
        if cardEffectEvent.from then
          prompt = "#slash-jink:" .. cardEffectEvent.from .. "::" .. 1
        end
        local use = self:askForUseCard(to, "jink", nil, prompt)
        if use then
          use.toCard = cardEffectEvent.card
          use.responseToEvent = cardEffectEvent
          self:useCard(use)
        end
      elseif cardEffectEvent.card.type == Card.TypeTrick and
        not cardEffectEvent.disresponsive then
        local players = {}
        for _, p in ipairs(self.alive_players) do
          local cards = p:getCardIds(Player.Hand)
          for _, cid in ipairs(cards) do
            if Fk:getCardById(cid).name == "nullification" and
              not table.contains(cardEffectEvent.disresponsiveList or {}, p.id) then
              table.insert(players, p)
              break
            end
          end
        end

        local prompt = ""
        if cardEffectEvent.to then
          prompt = "#AskForNullification::" .. cardEffectEvent.to .. ":" .. cardEffectEvent.card.name
        elseif cardEffectEvent.from then
          prompt = "#AskForNullificationWithoutTo:" .. cardEffectEvent.from .. "::" .. cardEffectEvent.card.name
        end
        local use = self:askForNullification(players, nil, nil, prompt)
        if use then
          use.toCard = cardEffectEvent.card
          use.responseToEvent = cardEffectEvent
          self:useCard(use)
        end
      end
    end

    if event == fk.CardEffecting then
      if cardEffectEvent.card.skill then
        cardEffectEvent.card.skill:onEffect(self, cardEffectEvent)
      end
    end
  end
end

---@param cardResponseEvent CardResponseEvent
function Room:responseCard(cardResponseEvent)
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
        table.insert(infos, {
          cardId = id,
          fromArea = self:getCardArea(id),
          fromSpecialName = cardsMoveInfo.from and self:getPlayerById(cardsMoveInfo.from):getPileNameOfId(id),
        })
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

  self:notifyMoveCards(nil, cardsMoveStructs)

  for _, data in ipairs(cardsMoveStructs) do
    if #data.moveInfo > 0 then
      infoCheck(data)

      ---@param info MoveInfo
      for _, info in ipairs(data.moveInfo) do
        local realFromArea = self:getCardArea(info.cardId)
        local playerAreas = { Player.Hand, Player.Equip, Player.Judge, Player.Special }

        if table.contains(playerAreas, realFromArea) and data.from then
          self:getPlayerById(data.from):removeCards(realFromArea, { info.cardId }, info.fromSpecialName)
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
        Fk:filterCard(info.cardId, self:getPlayerById(data.to))

        local currentCard = Fk:getCardById(info.cardId)
        if
          data.toArea == Player.Equip and
          currentCard.type == Card.TypeEquip and
          data.to ~= nil and
          self:getPlayerById(data.to):isAlive() and
          currentCard.equip_skill
        then
          currentCard:onInstall(self, self:getPlayerById(data.to))
        elseif realFromArea == Player.Equip and currentCard.type == Card.TypeEquip and data.from ~= nil and currentCard.equip_skill then
          currentCard:onUninstall(self, self:getPlayerById(data.from))
        end
      end
    end
  end

  self.logic:trigger(fk.AfterCardsMove, nil, cardsMoveStructs)
  return true
end

---@param player integer
---@param cid integer|Card
---@param unhide boolean
---@param reason CardMoveReason
function Room:obtainCard(player, cid, unhide, reason)
  if type(cid) ~= "number" then
    assert(cid and cid:isInstanceOf(Card))
    cid = cid:isVirtual() and cid.subcards or {cid.id}
  else
    cid = {cid}
  end
  if #cid == 0 then return end
  self:moveCards({
    ids = cid,
    from = self.owner_map[cid[1]],
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
---@param visible boolean
function Room:moveCardTo(card, to_place, target, reason, skill_name, special_name, visible)
  reason = reason or fk.ReasonJustMove
  skill_name = skill_name or ""
  special_name = special_name or ""
  local ids = Card:getIdList(card)

  local to
  if table.contains(
    {Card.PlayerEquip, Card.PlayerHand,
     Card.PlayerJudge, Card.PlayerSpecial}, to_place) then
    to = target.id
  end

  self:moveCards{
    ids = ids,
    from = self.owner_map[ids[1]],
    to = to,
    toArea = to_place,
    moveReason = reason,
    skillName = skill_name,
    specialName = special_name,
    moveVisible = visible,
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
  return execGameEvent(GameEvent.ChangeHp, player, num, reason, skillName, damageStruct)
end

---@param player ServerPlayer
---@param num integer
---@param skillName string
---@return boolean
function Room:loseHp(player, num, skillName)
  return execGameEvent(GameEvent.LoseHp, player, num, skillName)
end

---@param player ServerPlayer
---@param num integer
---@return boolean
function Room:changeMaxHp(player, num)
  return execGameEvent(GameEvent.ChangeMaxHp, player, num)
end

---@param damageStruct DamageStruct
---@return boolean
function Room:damage(damageStruct)
  return execGameEvent(GameEvent.Damage, damageStruct)
end

---@param recoverStruct RecoverStruct
---@return boolean
function Room:recover(recoverStruct)
  return execGameEvent(GameEvent.Recover, recoverStruct)
end

---@param dyingStruct DyingStruct
function Room:enterDying(dyingStruct)
  return execGameEvent(GameEvent.Dying, dyingStruct)
end

---@param deathStruct DeathStruct
function Room:killPlayer(deathStruct)
  return execGameEvent(GameEvent.Death, deathStruct)
end

-- lose/acquire skill actions

---@param player ServerPlayer
---@param skill_names string[] | string
---@param source_skill string | Skill | null
---@param no_trigger boolean | null
function Room:handleAddLoseSkills(player, skill_names, source_skill, sendlog, no_trigger)
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

  if (not no_trigger) and #triggers > 0 then
    for i = 1, #triggers do
      local event = losts[i] and fk.EventLoseSkill or fk.EventAcquireSkill
      self.logic:trigger(event, player, triggers[i])
    end
  end
end

-- judge

---@param data JudgeStruct
---@return Card
function Room:judge(data)
  local who = data.who
  self.logic:trigger(fk.StartJudge, who, data)
  data.card = Fk:getCardById(self:getNCards(1)[1])

  if data.reason ~= "" then
    self:sendLog{
      type = "#StartJudgeReason",
      from = who.id,
      arg = data.reason,
    }
  end

  self:sendLog{
    type = "#InitialJudge",
    from = who.id,
    card = {data.card.id},
  }
  self:moveCardTo(data.card, Card.Processing, nil, fk.ReasonPrey)

  self.logic:trigger(fk.AskForRetrial, who, data)
  self.logic:trigger(fk.FinishRetrial, who, data)
  Fk:filterCard(data.card.id, who, data)
  self:sendLog{
    type = "#JudgeResult",
    from = who.id,
    card = {data.card.id},
  }

  if data.pattern then
    self:delay(400);
    self:setCardEmotion(data.card.id, data.card:matchPattern(data.pattern) and "judgegood" or "judgebad")
    self:delay(900);
  end

  self.logic:trigger(fk.FinishJudge, who, data)
  if self:getCardArea(data.card.id) == Card.Processing then
    self:moveCardTo(data.card, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile)
  end
end

---@param card Card
---@param player ServerPlayer
---@param judge JudgeStruct
---@param skillName string
---@param exchange boolean
function Room:retrial(card, player, judge, skillName, exchange)
  if not card then return end
  local triggerResponded = self.owner_map[card:getEffectiveId()] == player
  local isHandcard = (triggerResponded and self:getCardArea(card:getEffectiveId()) == Card.PlayerHand)

  local oldJudge = judge.card
  judge.card = Fk:getCardById(card:getEffectiveId())
  local rebyre = judge.retrial_by_response
  judge.retrial_by_response = player

  local resp = {} ---@type CardResponseEvent
  resp.from = player.id
  resp.card = card

  if triggerResponded then
    self.logic:trigger(fk.PreCardRespond, player, resp)
  end

  local move1 = {} ---@type CardsMoveInfo
  move1.ids = { card:getEffectiveId() }
  move1.from = player.id
  move1.toArea = Card.Processing
  move1.moveReason = fk.ReasonResonpse
  move1.skillName = skillName

  local move2 = {} ---@type CardsMoveInfo
  move2.ids = { oldJudge:getEffectiveId() }
  move2.toArea = exchange and Card.PlayerHand or Card.DiscardPile
  move2.moveReason = fk.ReasonJustMove
  move2.to = exchange and player.id or nil

  self:sendLog{
    type = "#ChangedJudge",
    from = player.id,
    to = { judge.who.id },
    card = { card:getEffectiveId() },
    arg = skillName,
  }

  self:moveCards(move1, move2)

  if triggerResponded then
    self.logic:trigger(fk.CardRespondFinished, player, resp)
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

---@param pindianStruct PindianStruct
function Room:pindian(pindianStruct)

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

---@param player ServerPlayer
---@param skill Skill
---@param effect_cb fun()
function Room:useSkill(player, skill, effect_cb)
  if not skill.mute then
    if skill.attached_equip then
      local equip = Fk:cloneCard(skill.attached_equip)
      local pkgPath = "./packages/" .. equip.package.extensionName
      local soundName = pkgPath .. "/audio/card/" .. equip.name
      self:broadcastPlaySound(soundName)
      self:setEmotion(player, pkgPath .. "/image/anim/" .. equip.name)
    else
      self:broadcastSkillInvoke(skill.name)
      self:notifySkillInvoked(player, skill.name)
    end
  end
  player:addSkillUseHistory(skill.name)
  if effect_cb then
    return effect_cb()
  end
end

function Room:gameOver(winner)
  self.logic:trigger(fk.GameFinished, nil, winner)
  self.game_started = false
  self.game_finished = true

  for _, p in ipairs(self.players) do
    self:broadcastProperty(p, "role")
  end
  self:doBroadcastNotify("GameOver", winner)

  self.room:gameOver()
  coroutine.yield("__handleRequest")
end

---@param card Card
---@param fromAreas CardArea[]|null
---@return integer[]
function Room:getSubcardsByRule(card, fromAreas)
  if card:isVirtual() and #card.subcards == 0 then
    return {}
  end

  local cardIds = {}
  fromAreas = fromAreas or {}
  for _, cardId in ipairs(card:isVirtual() and card.subcards or { card.id }) do
    if #fromAreas == 0 or table.contains(fromAreas, self:getCardArea(cardId)) then
      table.insert(cardIds, cardId)
    end
  end

  return cardIds
end

function CreateRoom(_room)
  RoomInstance = Room:new(_room)
end
