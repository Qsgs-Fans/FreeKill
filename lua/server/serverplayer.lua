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
---@field private _fake_skills Skill[]
---@field private _manually_fake_skills Skill[]
---@field public prelighted_skills Skill[]
---@field private _timewaste_count integer
---@field public ai AI
---@field public ai_data any
local ServerPlayer = Player:subclass("ServerPlayer")

function ServerPlayer:initialize(_self)
  Player.initialize(self)
  self.serverplayer = _self -- 控制者
  self._splayer = _self -- 真正在玩的玩家
  self._observers = { _self } -- "旁观"中的玩家，然而不包括真正的旁观者
  self.id = _self:getId()
  self.room = nil

  -- Below are for doBroadcastRequest
  self.request_data = ""
  self.client_reply = ""
  self.default_reply = ""
  self.reply_ready = false
  self.reply_cancel = false
  self.phases = {}
  self.skipped_phases = {}

  self._fake_skills = {}
  self._manually_fake_skills = {}
  self.prelighted_skills = {}
  self._prelighted_skills = {}

  self._timewaste_count = 0
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
    if id == self.id and room.room:hasObserver(p) then
      p:doNotify(command, jsonData)
    end
  end
end

--- Send a request to client, and allow client to reply within *timeout* seconds.
---
--- *timeout* must not be negative. If nil, room.timeout is used.
---@param command string
---@param jsonData string
---@param timeout integer|nil
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

local function _waitForReply(player, timeout)
  local result
  local start = os.getms()
  local state = player.serverplayer:getState()
  player.request_timeout = timeout
  player.request_start = start
  if state ~= fk.Player_Online then
    if player.room.hasSurrendered then
      return "__cancel"
    end

    if state ~= fk.Player_Robot then
      player.room:checkNoHuman()
      player.room:delay(500)
      return "__cancel"
    end
    -- Let AI make reply. First handle request
    -- coroutine.yield("__handleRequest", 0)

    player.room:checkNoHuman()
    player.ai:readRequestData()
    local reply = player.ai:makeReply()
    if reply == "" then reply = "__cancel" end
    return reply
  end
  while true do
    player.serverplayer:setThinking(true)
    result = player.serverplayer:waitForReply(0)
    if result ~= "__notready" then
      player._timewaste_count = 0
      player.serverplayer:setThinking(false)
      return result
    end
    local rest = timeout * 1000 - (os.getms() - start) / 1000
    if timeout and rest <= 0 then
      if timeout >= 15 then
        player._timewaste_count = player._timewaste_count + 1
      end
      player.serverplayer:setThinking(false)

      if player._timewaste_count >= 3 then
        player._timewaste_count = 0
        player.serverplayer:emitKick()
      end

      return ""
    end

    if player.room.hasSurrendered then
      player.serverplayer:setThinking(false)
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
    self.serverplayer:setThinking(false)
  end
  if result ~= "" then
    self.reply_ready = true
    self.serverplayer:setBusy(false)
    self.serverplayer:setThinking(false)
  end

  local queue = self.room.request_queue[self.serverplayer]
  if queue and #queue > 0 and not self.serverplayer:busy() then
    local i, c, j, t = table.unpack(table.remove(queue, 1))
    self.room:getPlayerById(i):doRequest(c, j, t)
  end

  return result
end

---@param player ServerPlayer
---@param observe bool
function ServerPlayer:marshal(player, observe)
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

  for k, v in pairs(self.special_cards) do
    local info = {}
    for _, i in ipairs(v) do
      table.insert(info, { cardId = i, fromArea = Card.DrawPile })
    end
    local move = {
      moveInfo = info,
      to = self.id,
      toArea = Card.PlayerSpecial,
      specialName = k,
      specialVisible = self == player,
    }
    table.insert(card_moves, move)
  end

  if #card_moves > 0 then
    room:notifyMoveCards({ player }, card_moves, observe and self.seat == 1)
  end

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
    if v[4] > 0 then
      player:doNotify("SetSkillUseHistory", json.encode{self.id, k, v[1], 1})
      player:doNotify("SetSkillUseHistory", json.encode{self.id, k, v[2], 2})
      player:doNotify("SetSkillUseHistory", json.encode{self.id, k, v[3], 3})
      player:doNotify("SetSkillUseHistory", json.encode{self.id, k, v[4], 4})
    end
  end

  if self.role_shown then
    room:notifyProperty(player, self, "role")
  end

  if #self.sealedSlots > 0 then
    room:notifyProperty(player, self, "sealedSlots")
  end
end

function ServerPlayer:reconnect()
  local room = self.room
  self.serverplayer:setState(fk.Player_Online)

  self:doNotify("Setup", json.encode{
    self.id,
    self._splayer:getScreenName(),
    self._splayer:getAvatar(),
  })
  self:doNotify("EnterLobby", "")
  self:doNotify("EnterRoom", json.encode{
    #room.players, room.timeout, room.settings,
  })
  self:doNotify("StartGame", "")
  room:notifyProperty(self, self, "role")

  -- send player data
  for _, p in ipairs(room:getOtherPlayers(self, false, true)) do
    self:doNotify("AddPlayer", json.encode{
      p.id,
      p._splayer:getScreenName(),
      p._splayer:getAvatar(),
    })
  end
  self:doNotify("RoomOwner", json.encode{ room.room:getOwner():getId() })

  local player_circle = {}
  for i = 1, #room.players do
    table.insert(player_circle, room.players[i].id)
  end
  self:doNotify("ArrangeSeats", json.encode(player_circle))

  -- send printed_cards
  for i = -2, -math.huge, -1 do
    local c = Fk.printed_cards[i]
    if not c then break end
    self:doNotify("PrintCard", json.encode{ c.name, c.suit, c.number })
  end

  -- send card marks
  for id, marks in pairs(room.card_marks) do
    for k, v in pairs(marks) do
      self:doNotify("SetCardMark", json.encode{ id, k, v })
    end
  end

  for _, p in ipairs(room.players) do
    room:notifyProperty(self, p, "general")
    room:notifyProperty(self, p, "deputyGeneral")
    p:marshal(self)
  end

  self:doNotify("UpdateDrawPile", #room.draw_pile)
  self:doNotify("UpdateRoundNum", room:getTag("RoundCount") or 0)

  -- send fake skills
  for _, s in ipairs(self._manually_fake_skills) do
    self:doNotify("AddSkill", json.encode{ self.id, s.name, true })
    if table.contains(self.prelighted_skills, s) then
      self:doNotify("PrelightSkill", json.encode{ s.name, true })
    end
  end

  room:broadcastProperty(self, "state")
end

function ServerPlayer:isAlive()
  return self.dead == false
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
  for _, id in ipairs(cards) do
    Fk:filterCard(id, self)
  end

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
  room:sendFootnote(cards, {
    type = "##ShowCard",
    from = self.id,
  })

  room.logic:trigger(fk.CardShown, self, { cardIds = cards })
end

local phase_name_table = {
  [Player.Judge] = "phase_judge",
  [Player.Draw] = "phase_draw",
  [Player.Play] = "phase_play",
  [Player.Discard] = "phase_discard",
}

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
  room:broadcastProperty(self, "phase")

  if #self.phases > 0 then
    table.remove(self.phases, 1)
  end

  GameEvent(GameEvent.Phase, self, self.phase):exec()

  return false
end

function ServerPlayer:gainAnExtraPhase(phase, delay)
  local room = self.room
  delay = (delay == nil) and true or delay
  if delay then
    local logic = room.logic
    local turn = logic:getCurrentEvent():findParent(GameEvent.Phase, true)
    if turn then
      turn:prependExitFunc(function() self:gainAnExtraPhase(phase, false) end)
      return
    end
  end

  local current = self.phase
  self.phase = phase
  room:broadcastProperty(self, "phase")

  room:sendLog{
    type = "#GainAnExtraPhase",
    from = self.id,
    arg = phase_name_table[phase],
  }

  GameEvent(GameEvent.Phase, self, self.phase):exec()

  self.phase = current
  room:broadcastProperty(self, "phase")
end

---@param phase_table Phase[]|nil
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
    room:broadcastProperty(self, "phase")

    local cancel_skip = true
    if phases[i] ~= Player.NotActive and (skip) then
      cancel_skip = logic:trigger(fk.EventPhaseSkipping, self)
    end

    if (not skip) or (cancel_skip) then
      GameEvent(GameEvent.Phase, self, self.phase):exec()
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

--- 当进行到出牌阶段空闲点时，结束出牌阶段。
function ServerPlayer:endPlayPhase()
  self._play_phase_end = true
  -- TODO: send log
end

function ServerPlayer:gainAnExtraTurn(delay)
  local room = self.room
  delay = (delay == nil) and true or delay
  if delay then
    local logic = room.logic
    local turn = logic:getCurrentEvent():findParent(GameEvent.Turn, true)
    if turn then
      turn:prependExitFunc(function() self:gainAnExtraTurn(false) end)
      return
    end
  end

  room:sendLog{
    type = "#GainAnExtraTurn",
    from = self.id
  }

  local current = room.current
  room.current = self

  self.tag["_extra_turn_count"] = self.tag["_extra_turn_count"] or {}
  local ex_tag = self.tag["_extra_turn_count"]
  local skillName = room.logic:getCurrentSkillName()
  table.insert(ex_tag, skillName)

  GameEvent(GameEvent.Turn, self):exec()

  table.remove(ex_tag)

  room.current = current
end

function ServerPlayer:insideExtraTurn()
  return self.tag["_extra_turn_count"] and #self.tag["_extra_turn_count"] > 0
end

---@return string
function ServerPlayer:getCurrentExtraTurnReason()
  local ex_tag = self.tag["_extra_turn_count"]
  if (not ex_tag) or #ex_tag == 0 then
    return "game_rule"
  end
  return ex_tag[#ex_tag]
end

function ServerPlayer:drawCards(num, skillName, fromPlace)
  return self.room:drawCards(self, num, skillName, fromPlace)
end

---@param pile_name string
---@param card integer|Card
---@param visible boolean
---@param skillName string|nil
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
  self:reset()
end

function ServerPlayer:throwAllCards(flag)
  local cardIds = {}
  flag = flag or "hej"
  if string.find(flag, "h") then
    table.insertTable(cardIds, self.player_cards[Player.Hand])
  end

  if string.find(flag, "e") then
    table.insertTable(cardIds, self.player_cards[Player.Equip])
  end

  if string.find(flag, "j") then
    table.insertTable(cardIds, self.player_cards[Player.Judge])
  end

  self.room:throwCard(cardIds, "", self)
end

function ServerPlayer:throwAllMarks()
  for name, _ in pairs(self.mark) do
    self.room:setPlayerMark(self, name, 0)
  end
end

function ServerPlayer:clearPiles()
  local cardIds = {}
  for _, ids in pairs(self.special_cards) do
    table.insertTable(cardIds, ids)
  end
  self.room:moveCardTo(cardIds, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile, "", nil, true)
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
  local room = self.room
  if room.logic:trigger(fk.BeforeChainStateChange, self) then
    return
  end

  self.chained = chained

  room:broadcastProperty(self, "chained")
  room:sendLog{
    type = "#ChainStateChange",
    from = self.id,
    arg = self.chained and "chained" or "un-chained"
  }
  room:delay(150)
  room:broadcastPlaySound("./audio/system/chain")
  room.logic:trigger(fk.ChainStateChanged, self)
end

function ServerPlayer:reset()
  if self.faceup and not self.chained then return end
  self.room:sendLog{
    type = "#ChainStateChange",
    from = self.id,
    arg = "reset-general"
  }
  if self.chained then self:setChainState(false) end
  if not self.faceup then self:turnOver() end
end

--- 进行拼点。
---@param from ServerPlayer
---@param tos ServerPlayer[]
---@param skillName string
---@param initialCard Card|nil
---@return PindianStruct
function ServerPlayer:pindian(tos, skillName, initialCard)
  local pindianData = { from = self, tos = tos, reason = skillName, fromCard = initialCard, results = {} }
  self.room:pindian(pindianData)
  return pindianData
end

--- 播放技能的语音。
---@param skill_name string @ 技能名
---@param index integer | nil @ 语音编号，默认为-1（也就是随机播放）
function ServerPlayer:broadcastSkillInvoke(skill_name, index)
  index = index or -1
  self.room:sendLogEvent("PlaySkillSound", {
    name = skill_name,
    i = index,
    general = self.general,
    deputy = self.deputyGeneral,
  })
end

-- Hegemony func

---@param skill Skill
function ServerPlayer:addFakeSkill(skill)
  assert(type(skill) == "string" or skill:isInstanceOf(Skill))
  if type(skill) == "string" then
    skill = Fk.skills[skill]
  end
  if table.contains(self._fake_skills, skill) then return end

  table.insertIfNeed(self._manually_fake_skills, skill)

  table.insert(self._fake_skills, skill)
  for _, s in ipairs(skill.related_skills) do
    -- if s.main_skill == skill then -- TODO: need more detailed
      table.insert(self._fake_skills, s)
    -- end
  end

  -- TODO
  self:doNotify("AddSkill", json.encode{ self.id, skill.name, true })
end

---@param skill Skill
function ServerPlayer:loseFakeSkill(skill)
  assert(type(skill) == "string" or skill:isInstanceOf(Skill))
  if type(skill) == "string" then
    skill = Fk.skills[skill]
  end
  if not table.contains(self._fake_skills, skill) then return end

  table.removeOne(self._manually_fake_skills, skill)

  table.removeOne(self._fake_skills, skill)
  for _, s in ipairs(skill.related_skills) do
    table.removeOne(self._fake_skills, s)
  end

  -- TODO
  self:doNotify("LoseSkill", json.encode{ self.id, skill.name, true })
end

function ServerPlayer:isFakeSkill(skill)
  if type(skill) == "string" then skill = Fk.skills[skill] end
  assert(skill:isInstanceOf(Skill))
  return table.contains(self._fake_skills, skill)
end

---@param skill string | Skill
---@param isPrelight bool
function ServerPlayer:prelightSkill(skill, isPrelight)
  if type(skill) == "string" then skill = Fk.skills[skill] end
  assert(skill:isInstanceOf(Skill))

  if not self._prelighted_skills[skill] and not self:hasSkill(skill) then
    self._prelighted_skills[skill] = true
    -- to attach skill to room
    self:addSkill(skill)
    self:loseSkill(skill)
  end

  if isPrelight then
    -- self:addSkill(skill)
    table.insert(self.prelighted_skills, skill)
    for _, s in ipairs(skill.related_skills) do
      table.insert(self.prelighted_skills, s)
    end
  else
    -- self:loseSkill(skill)
    table.removeOne(self.prelighted_skills, skill)
    for _, s in ipairs(skill.related_skills) do
      table.removeOne(self.prelighted_skills, s)
    end
  end

  self:doNotify("PrelightSkill", json.encode{ skill.name, isPrelight })
end

---@param isDeputy bool
---@param no_trigger bool
function ServerPlayer:revealGeneral(isDeputy, no_trigger)
  local room = self.room
  local generalName
  if isDeputy then
    if self.deputyGeneral ~= "anjiang" then return end
    generalName = self:getMark("__heg_deputy")
  else
    if self.general ~= "anjiang" then return end
    generalName = self:getMark("__heg_general")
  end

  local general = Fk.generals[generalName] or Fk.generals["blank_shibing"]
  for _, s in ipairs(general:getSkillNameList()) do
    local skill = Fk.skills[s]
    self:loseFakeSkill(skill)
  end

  local ret = true
  if not ((isDeputy and self.general ~= "anjiang") or (not isDeputy and self.deputyGeneral ~= "anjiang")) then
    local other = Fk.generals[self:getMark(isDeputy and "__heg_general" or "__heg_deputy")] or Fk.generals["blank_shibing"]
    for _, sname in ipairs(other:getSkillNameList()) do
      local s = Fk.skills[sname]
      if s.frequency == Skill.Compulsory and s.relate_to_place ~= (isDeputy and "m" or "d") then
        ret = false
        break
      end
    end
  end
  if ret then
    self:loseFakeSkill("reveal_skill")
  end

  local oldKingdom = self.kingdom
  room:changeHero(self, generalName, false, isDeputy, false, false, false)
  if oldKingdom ~= "wild" then
    local kingdom = (self:getMark("__heg_wild") == 1 and not isDeputy) and "wild" or self:getMark("__heg_kingdom")
    self.kingdom = kingdom
    if oldKingdom == "unknown" and kingdom ~= "wild" and #table.filter(room:getOtherPlayers(self, false, true),
      function(p)
        return p.kingdom == kingdom
      end) >= #room.players // 2 and table.every(room.alive_players, function(p) return p.kingdom ~= kingdom or not string.find(p.general, "lord") end) then
      self.kingdom = "wild"
    end
    room:broadcastProperty(self, "kingdom")
  else
    room:setPlayerProperty(self, "kingdom", "wild")
  end

  if self.gender == General.Agender or self.gender ~= Fk.generals[self.general].gender then
    room:setPlayerProperty(self, "gender", general.gender)
  end

  room:sendLog{
    type = "#RevealGeneral",
    from = self.id,
    arg = isDeputy and "deputyGeneral" or "mainGeneral",
    arg2 = generalName,
  }

  if not no_trigger then
    room.logic:trigger(fk.GeneralRevealed, self, generalName)
  end
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

function ServerPlayer:hideGeneral(isDeputy)
  local room = self.room
  local generalName = isDeputy and self.deputyGeneral or self.general
  local mark = isDeputy and "__heg_deputy" or "__heg_general"

  self:setMark(mark, generalName)
  self:doNotify("SetPlayerMark", json.encode{ self.id, mark, generalName})

  if isDeputy then
    room:setDeputyGeneral(self, "anjiang")
    room:broadcastProperty(self, "deputyGeneral")
  else
    room:setPlayerGeneral(self, "anjiang", false)
    room:broadcastProperty(self, "general")
  end

  local general = Fk.generals[generalName]
  local skills = general.skills
  local place = isDeputy and "m" or "d"
  for _, s in ipairs(skills) do
    room:handleAddLoseSkills(self, "-" .. s.name, nil, false, true)
    if s.relate_to_place ~= place then
      if s.frequency == Skill.Compulsory then
        self:addFakeSkill("reveal_skill")
      end
      self:addFakeSkill(s)
    end
  end
  for _, sname in ipairs(general.other_skills) do
    room:handleAddLoseSkills(self, "-" .. sname, nil, false, true)
    local s = Fk.skills[sname]
    if s.relate_to_place ~= place then
      if s.frequency == Skill.Compulsory then
        self:addFakeSkill("reveal_skill")
      end
      self:addFakeSkill(s)
    end
  end

  self.gender = General.Agender
  if Fk.generals[self.general].gender ~= General.Agender then
    self.gender = Fk.generals[self.general].gender
  elseif self.deputyGeneral and Fk.generals[self.deputyGeneral].gender ~= General.Agender then
    self.gender = Fk.generals[self.deputyGeneral].gender
  end
  room:broadcastProperty(self, "gender")

  room.logic:trigger(fk.GeneralHidden, self, generalName)
end

-- 神貂蝉

---@param p ServerPlayer
function ServerPlayer:control(p)
  if self == p then
    self.room:setPlayerMark(p, "@ControledBy", 0)
  else
    self.room:setPlayerMark(p, "@ControledBy", "seat#" .. self.seat)
  end
  p.serverplayer = self._splayer
end

-- 22

function ServerPlayer:addBuddy(other)
  if type(other) == "number" then
    other = self.room:getPlayerById(other)
  end
  Player.addBuddy(self, other)
  self:doNotify("AddBuddy", json.encode{ other.id, other.player_cards[Player.Hand] })
end

function ServerPlayer:removeBuddy(other)
  if type(other) == "number" then
    other = self.room:getPlayerById(other)
  end
  Player.removeBuddy(self, other)
  self:doNotify("RmBuddy", tostring(other.id))
end

return ServerPlayer
