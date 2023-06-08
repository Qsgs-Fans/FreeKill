-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ServerPlayer : Player
---@field public serverplayer fk.ServerPlayer
---@field public room Room
---@field public next ServerPlayer
---@field public request_data string
---@field public client_reply string
---@field public default_reply string
---@field public reply_ready boolean
---@field public reply_cancel boolean
---@field public phases Phase[]
---@field public skipped_phases Phase[]
---@field public phase_state table[]
---@field public phase_index integer
---@field public role_shown boolean
---@field public ai AI
---@field public ai_data any
local ServerPlayer = Player:subclass("ServerPlayer")

function ServerPlayer:initialize(_self)
  Player.initialize(self)
  self.serverplayer = _self -- 控制者
  self._splayer = _self -- 真正在玩的玩家
  self._observers = { _self } -- "旁观"中的玩家，然而不包括真正的旁观者
  self.id = _self:getId()
  self.state = _self:getStateString()
  self.room = nil

  -- Below are for doBroadcastRequest
  self.request_data = ""
  self.client_reply = ""
  self.default_reply = ""
  self.reply_ready = false
  self.reply_cancel = false
  self.phases = {}
  self.skipped_phases = {}
  self.ai = RandomAI:new(self)
end

---@param command string
---@param jsonData string
function ServerPlayer:doNotify(command, jsonData)
  for _, p in ipairs(self._observers) do
    p:doNotify(command, jsonData)
  end

  local room = self.room
  for _, t in ipairs(room.observers) do
    local id, p = table.unpack(t)
    if id == self.id then
      p:doNotify(command, jsonData)
    end
  end
end

--- Send a request to client, and allow client to reply within *timeout* seconds.
---
--- *timeout* must not be negative. If nil, room.timeout is used.
---@param command string
---@param jsonData string
---@param timeout integer
function ServerPlayer:doRequest(command, jsonData, timeout)
  self.client_reply = ""
  self.reply_ready = false
  self.reply_cancel = false

  if self.serverplayer:busy() then
    self.room.request_queue[self.serverplayer] = self.room.request_queue[self.serverplayer] or {}
    table.insert(self.room.request_queue[self.serverplayer], { self.id, command, jsonData, timeout })
    return
  end

  self.room.request_self[self.serverplayer:getId()] = self.id

  if not table.contains(self._observers, self.serverplayer) then
    self.serverplayer:doNotify("StartChangeSelf", tostring(self.id))
  end

  timeout = timeout or self.room.timeout
  self.serverplayer:setBusy(true)
  self.ai_data = {
    command = command,
    jsonData = jsonData,
  }
  self.serverplayer:doRequest(command, jsonData, timeout)
end

local function checkNoHuman(room)
  for _, p in ipairs(room.players) do
    -- TODO: trust
    if p.serverplayer:getStateString() == "online" then
      return
    end
  end
  room:gameOver("")
end


local function _waitForReply(player, timeout)
  local result
  local start = os.getms()
  local state = player.serverplayer:getStateString()
  if state ~= "online" then
    if state ~= "robot" then
      checkNoHuman(player.room)
      player.room:delay(500)
      return "__cancel"
    end
    -- Let AI make reply. First handle request
    local ret_msg = true
    while ret_msg do
      -- when ret_msg is false, that means there is no request in the queue
      ret_msg = coroutine.yield("__handleRequest", 1)
    end

    checkNoHuman(player.room)
    player.ai:readRequestData()
    local reply = player.ai:makeReply()
    return reply
  end
  while true do
    result = player.serverplayer:waitForReply(0)
    if result ~= "__notready" then
      return result
    end
    local rest = timeout * 1000 - (os.getms() - start) / 1000
    if timeout and rest <= 0 then
      return ""
    end
    coroutine.yield("__handleRequest", rest)
  end
end

--- Wait for at most *timeout* seconds for reply from client.
---
--- If *timeout* is negative or **nil**, the function will wait forever until get reply.
---@param timeout integer @ seconds to wait
---@return string @ JSON data
function ServerPlayer:waitForReply(timeout)
  local result = _waitForReply(self, timeout)
  local sid = self.serverplayer:getId()
  local id = self.id
  if self.room.request_self[sid] ~= id then
    result = ""
  end

  self.request_data = ""
  self.client_reply = result
  if result == "__cancel" then
    result = ""
    self.reply_cancel = true
    self.serverplayer:setBusy(false)
  end
  if result ~= "" then
    self.reply_ready = true
    self.serverplayer:setBusy(false)
  end

  local queue = self.room.request_queue[self.serverplayer]
  if queue and #queue > 0 and not self.serverplayer:busy() then
    local i, c, j, t = table.unpack(table.remove(queue, 1))
    self.room:getPlayerById(i):doRequest(c, j, t)
  end

  return result
end

---@param player ServerPlayer
function ServerPlayer:marshal(player)
  local room = self.room
  if not room.game_started then
    -- If game does not starts, that mean we are entering room that
    -- all players are choosing their generals.
    -- Note that when we are in this function, the main thread must be
    -- calling delay() or waiting for reply.
    if self.role_shown then
      room:notifyProperty(player, self, "role")
    end
    return
  end

  room:notifyProperty(player, self, "maxHp")
  room:notifyProperty(player, self, "hp")
  room:notifyProperty(player, self, "shield")
  room:notifyProperty(player, self, "gender")
  room:notifyProperty(player, self, "kingdom")

  if self.kingdom ~= Fk.generals[self.general].kingdom then
    self.kingdom = Fk.generals[self.general].kingdom
    room:notifyProperty(player, self, "kingdom")
  end

  if self.dead then
    room:notifyProperty(player, self, "dead")
    room:notifyProperty(player, self, "role")
  else
    room:notifyProperty(player, self, "seat")
    room:notifyProperty(player, self, "phase")
  end

  if not self.faceup then
    room:notifyProperty(player, self, "faceup")
  end

  if self.chained then
    room:notifyProperty(player, self, "chained")
  end

  local card_moves = {}
  if #self.player_cards[Player.Hand] ~= 0 then
    local info = {}
    for _, i in ipairs(self.player_cards[Player.Hand]) do
      table.insert(info, { cardId = i, fromArea = Card.DrawPile })
    end
    local move = {
      moveInfo = info,
      to = self.id,
      toArea = Card.PlayerHand
    }
    table.insert(card_moves, move)
  end
  if #self.player_cards[Player.Equip] ~= 0 then
    local info = {}
    for _, i in ipairs(self.player_cards[Player.Equip]) do
      table.insert(info, { cardId = i, fromArea = Card.DrawPile })
    end
    local move = {
      moveInfo = info,
      to = self.id,
      toArea = Card.PlayerEquip
    }
    table.insert(card_moves, move)
  end
  if #self.player_cards[Player.Judge] ~= 0 then
    local info = {}
    for _, i in ipairs(self.player_cards[Player.Judge]) do
      table.insert(info, { cardId = i, fromArea = Card.DrawPile })
    end
    local move = {
      moveInfo = info,
      to = self.id,
      toArea = Card.PlayerJudge
    }
    table.insert(card_moves, move)
  end
  if #card_moves > 0 then
    room:notifyMoveCards({ player }, card_moves)
  end

  -- TODO: pile

  for k, v in pairs(self.mark) do
    player:doNotify("SetPlayerMark", json.encode{self.id, k, v})
  end

  for _, s in ipairs(self.player_skills) do
    player:doNotify("AddSkill", json.encode{self.id, s.name})
  end

  for k, v in pairs(self.cardUsedHistory) do
    if v[1] > 0 then
      player:doNotify("AddCardUseHistory", json.encode{k, v[1]})
    end
  end

  for k, v in pairs(self.skillUsedHistory) do
    if v[1] > 0 then
      player:doNotify("AddSkillUseHistory", json.encode{self.id, k, v[1]})
    end
  end

  if self.role_shown then
    room:notifyProperty(player, self, "role")
  end
end

function ServerPlayer:reconnect()
  local room = self.room
  self.serverplayer:setStateString("online")

  self:doNotify("Setup", json.encode{
    self.id,
    self.serverplayer:getScreenName(),
    self.serverplayer:getAvatar(),
  })
  self:doNotify("EnterLobby", "")
  self:doNotify("EnterRoom", json.encode{
    #room.players, room.timeout, room.settings,
  })
  self:doNotify("StartGame", "")
  room:notifyProperty(self, self, "role")

  -- send player data
  for _, p in ipairs(room:getOtherPlayers(self, true, true)) do
    self:doNotify("AddPlayer", json.encode{
      p.id,
      p.serverplayer:getScreenName(),
      p.serverplayer:getAvatar(),
    })
  end

  local player_circle = {}
  for i = 1, #room.players do
    table.insert(player_circle, room.players[i].id)
  end
  self:doNotify("ArrangeSeats", json.encode(player_circle))

  for _, p in ipairs(room.players) do
    room:notifyProperty(self, p, "general")
    room:notifyProperty(self, p, "deputyGeneral")
    p:marshal(self)
  end

  self:doNotify("UpdateDrawPile", #room.draw_pile)
  self:doNotify("UpdateRoundNum", room:getTag("RoundCount") or 0)

  room:broadcastProperty(self, "state")
end

function ServerPlayer:isAlive()
  return self.dead == false
end

function ServerPlayer:getNextAlive()
  if #self.room.alive_players == 0 then
    return self
  end

  local ret = self.next
  while ret.dead do
    ret = ret.next
  end
  return ret
end

function ServerPlayer:turnOver()
  if self.room.logic:trigger(fk.BeforeTurnOver, self) then
    return
  end

  self.faceup = not self.faceup
  self.room:broadcastProperty(self, "faceup")

  self.room:sendLog{
    type = "#TurnOver",
    from = self.id,
    arg = self.faceup and "face_up" or "face_down",
  }

  self.room.logic:trigger(fk.TurnedOver, self)
end

function ServerPlayer:showCards(cards)
  cards = Card:getIdList(cards)
  local room = self.room
  room:sendLog{
    type = "#ShowCard",
    from = self.id,
    card = cards,
  }
  room:doBroadcastNotify("ShowCard", json.encode{
    from = self.id,
    cards = cards,
  })

  room.logic:trigger(fk.CardShown, self, { cardIds = cards })
end

---@param from_phase Phase
---@param to_phase Phase
function ServerPlayer:changePhase(from_phase, to_phase)
  local room = self.room
  local logic = room.logic
  self.phase = Player.PhaseNone

  local phase_change = {
    from = from_phase,
    to = to_phase
  }

  local skip = logic:trigger(fk.EventPhaseChanging, self, phase_change)
  if skip and to_phase ~= Player.NotActive then
    self.phase = from_phase
    return true
  end

  self.phase = to_phase
  room:notifyProperty(self, self, "phase")

  if #self.phases > 0 then
    table.remove(self.phases, 1)
  end

  GameEvent(GameEvent.Phase, self):exec()

  return false
end

function ServerPlayer:gainAnExtraPhase(phase, delay)
  local room = self.room
  delay = (delay == nil) and true or delay
  if delay then
    local logic = room.logic
    local turn = logic:getCurrentEvent():findParent(GameEvent.Phase, true)
    if turn then
      turn:addExitFunc(function() self:gainAnExtraPhase(phase, false) end)
      return
    end
  end

  local current = self.phase
  self.phase = phase
  room:notifyProperty(self, self, "phase")

  GameEvent(GameEvent.Phase, self):exec()

  self.phase = current
  room:notifyProperty(self, self, "phase")
end

local phase_name_table = {
  [Player.Judge] = "phase_judge",
  [Player.Draw] = "phase_draw",
  [Player.Play] = "phase_play",
  [Player.Discard] = "phase_discard",
}

---@param phase_table Phase[]
function ServerPlayer:play(phase_table)
  phase_table = phase_table or {}
  if #phase_table > 0 then
    if not table.contains(phase_table, Player.NotActive) then
      table.insert(phase_table, Player.NotActive)
    end
  else
    phase_table = {
      Player.RoundStart, Player.Start,
      Player.Judge, Player.Draw, Player.Play, Player.Discard,
      Player.Finish, Player.NotActive,
    }
  end

  self.phases = phase_table
  self.phase_state = {}

  local phases = self.phases
  local phase_state = self.phase_state
  local room = self.room

  for i = 1, #phases do
    phase_state[i] = {
      phase = phases[i],
      skipped = self.skipped_phases[phases[i]] or false
    }
  end

  for i = 1, #phases do
    if self.dead then
      self:changePhase(self.phase, Player.NotActive)
      break
    end

    self.phase_index = i
    local phase_change = {
      from = self.phase,
      to = phases[i]
    }

    local logic = self.room.logic
    self.phase = Player.PhaseNone

    local skip = phase_state[i].skipped
    if not skip then
      skip = logic:trigger(fk.EventPhaseChanging, self, phase_change)
    end
    phases[i] = phase_change.to
    phase_state[i].phase = phases[i]

    self.phase = phases[i]
    room:notifyProperty(self, self, "phase")

    local cancel_skip = true
    if phases[i] ~= Player.NotActive and (skip) then
      cancel_skip = logic:trigger(fk.EventPhaseSkipping, self)
    end

    if (not skip) or (cancel_skip) then
      GameEvent(GameEvent.Phase, self):exec()
    else
      room:sendLog{
        type = "#PhaseSkipped",
        from = self.id,
        arg = phase_name_table[self.phase],
      }
    end
  end
end

---@param phase Phase
function ServerPlayer:skip(phase)
  if not table.contains({
    Player.Judge,
    Player.Draw,
    Player.Play,
    Player.Discard
  }, phase) then
    return
  end
  self.skipped_phases[phase] = true
  for _, t in ipairs(self.phase_state) do
    if t.phase == phase then
      t.skipped = true
    end
  end
end

function ServerPlayer:gainAnExtraTurn(delay)
  local room = self.room
  delay = (delay == nil) and true or delay
  if delay then
    local logic = room.logic
    local turn = logic:getCurrentEvent():findParent(GameEvent.Turn, true)
    if turn then
      turn:addExitFunc(function() self:gainAnExtraTurn(false) end)
      return
    end
  end

  room:sendLog{
    type = "#GainAnExtraTurn",
    from = self.id
  }

  local current = room.current
  room.current = self
  GameEvent(GameEvent.Turn):exec()
  room.current = current
end

function ServerPlayer:drawCards(num, skillName, fromPlace)
  return self.room:drawCards(self, num, skillName, fromPlace)
end

---@param pile_name string
---@param card integer|Card
---@param visible boolean
---@param skillName string
function ServerPlayer:addToPile(pile_name, card, visible, skillName)
  local room = self.room
  room:moveCardTo(card, Card.PlayerSpecial, self, fk.ReasonJustMove, skillName, pile_name, visible)
end

function ServerPlayer:bury()
  self:setCardUseHistory("")
  self:setSkillUseHistory("")
  self:throwAllCards()
  self:throwAllMarks()
  self:clearPiles()
  self:setChainState(false)
  if not self.faceup then self:turnOver() end
end

function ServerPlayer:throwAllCards(flag)
  local room = self.room
  flag = flag or "hej"
  if string.find(flag, "h") then
    room:throwCard(self.player_cards[Player.Hand], "", self)
  end

  if string.find(flag, "e") then
    room:throwCard(self.player_cards[Player.Equip], "", self)
  end

  if string.find(flag, "j") then
    room:throwCard(self.player_cards[Player.Judge], "", self)
  end
end

function ServerPlayer:throwAllMarks()
  for name, _ in pairs(self.mark) do
    self.room:setPlayerMark(self, name, 0)
  end
end

function ServerPlayer:clearPiles()
  for _, ids in pairs(self.special_cards) do
    self.room:throwCard(ids, "", self)
  end
end

function ServerPlayer:addVirtualEquip(card)
  Player.addVirtualEquip(self, card)
  self.room:doBroadcastNotify("AddVirtualEquip", json.encode{
    player = self.id,
    name = card.name,
    subcards = card.subcards,
  })
end

function ServerPlayer:removeVirtualEquip(cid)
  local ret = Player.removeVirtualEquip(self, cid)
  self.room:doBroadcastNotify("RemoveVirtualEquip", json.encode{
    player = self.id,
    id = cid,
  })
  return ret
end

function ServerPlayer:addCardUseHistory(cardName, num)
  Player.addCardUseHistory(self, cardName, num)
  self:doNotify("AddCardUseHistory", json.encode{cardName, num})
end

function ServerPlayer:setCardUseHistory(cardName, num, scope)
  Player.setCardUseHistory(self, cardName, num, scope)
  self:doNotify("SetCardUseHistory", json.encode{cardName, num, scope})
end

function ServerPlayer:addSkillUseHistory(cardName, num)
  Player.addSkillUseHistory(self, cardName, num)
  self.room:doBroadcastNotify("AddSkillUseHistory", json.encode{self.id, cardName, num})
end

function ServerPlayer:setSkillUseHistory(cardName, num, scope)
  Player.setSkillUseHistory(self, cardName, num, scope)
  self.room:doBroadcastNotify("SetSkillUseHistory", json.encode{self.id, cardName, num, scope})
end

---@param chained boolean
function ServerPlayer:setChainState(chained)
  if self.room.logic:trigger(fk.BeforeChainStateChange, self) then
    return
  end

  self.chained = chained
  self.room:broadcastProperty(self, "chained")
  self.room:sendLog{
    type = "#ChainStateChange",
    from = self.id,
    arg = self.chained and "chained" or "not-chained"
  }

  self.room.logic:trigger(fk.ChainStateChanged, self)
end

---@param from ServerPlayer
---@param tos ServerPlayer[]
---@param skillName string
---@param initialCard Card
---@return PindianStruct
function ServerPlayer:pindian(tos, skillName, initialCard)
  local pindianData = { from = self, tos = tos, reason = skillName, fromCard = initialCard, results = {} }
  self.room:pindian(pindianData)
  return pindianData
end

-- Hegemony func

function ServerPlayer:prelightSkill(skill, isPrelight)
  if isPrelight then
    self:addSkill(skill)
  else
    self:loseSkill(skill)
  end
  self:doNotify("PrelightSkill", json.encode{ skill, isPrelight })
end

function ServerPlayer:revealGeneral(isDeputy)
  local room = self.room
  local generalName
  if isDeputy then
    if self.deputyGeneral ~= "anjiang" then return end
    generalName = self:getMark("__heg_deputy")
  else
    if self.general ~= "anjiang" then return end
    generalName = self:getMark("__heg_general")
  end

  local general = Fk.generals[generalName]
  for _, s in ipairs(general:getSkillNameList()) do
    local skill = Fk.skills[s]
    if skill:isInstanceOf(TriggerSkill) or table.find(skill.related_skills,
      function(s) return s:isInstanceOf(TriggerSkill) end) then
      self:doNotify("LoseSkill", json.encode{ self.id, s, true })
    end
  end

  local oldKingdom = self.kingdom
  room:changeHero(self, generalName, false, isDeputy)
  local kingdom = general.kingdom
  if oldKingdom == "unknown" and #table.filter(room:getOtherPlayers(self),
    function(p)
      return p.kingdom == kingdom
    end) >= #room.players // 2 then

    self.kingdom = "wild"
    room:broadcastProperty(self, "kingdom")
  end

  if self.gender ~= General.Male and self.gender ~= General.Female then
    self.gender = general.gender
  end

  room:sendLog{
    type = "#RevealGeneral",
    from = self.id,
    arg = isDeputy and "deputyGeneral" or "mainGeneral",
    arg2 = generalName,
  }

  -- TODO: 阴阳鱼摸牌
end

function ServerPlayer:revealBySkillName(skill_name)
  local main = self.general == "anjiang"
  local deputy = self.deputyGeneral == "anjiang"

  if main then
    if table.contains(Fk.generals[self:getMark("__heg_general")]
      :getSkillNameList(), skill_name) then
      self:revealGeneral(false)
      return
    end
  end

  if deputy then
    if table.contains(Fk.generals[self:getMark("__heg_deputy")]
      :getSkillNameList(), skill_name) then
      self:revealGeneral(true)
      return
    end
  end
end

-- 神貂蝉

function ServerPlayer:control(p)
  if self == p then
    self.room:setPlayerMark(p, "@ControledBy", 0)
  else
    self.room:setPlayerMark(p, "@ControledBy", "seat#" .. self.seat)
  end
  p.serverplayer = self._splayer
end

return ServerPlayer
