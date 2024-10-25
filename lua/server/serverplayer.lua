-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ServerPlayer : Player
---@field public serverplayer fk.ServerPlayer
---@field public room Room
---@field public next ServerPlayer
---@field public request_data string
---@field public mini_game_data any
---@field public client_reply string
---@field public default_reply string
---@field public reply_ready boolean
---@field public reply_cancel boolean
---@field public phases Phase[]
---@field public skipped_phases Phase[]
---@field public phase_state table[]
---@field public phase_index integer
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
  -- 但是几乎全部被船新request杀了
  self.request_data = ""
  --self.client_reply = ""
  self.default_reply = ""
  --self.reply_ready = false
  --self.reply_cancel = false
  self.phases = {}
  self.skipped_phases = {}
  self.phase_state = {}

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
  local room = self.room
  for _, p in ipairs(self._observers) do
    if p:getState() ~= fk.Player_Robot then
      room.notify_count = room.notify_count + 1
    end
    p:doNotify(command, jsonData)
  end

  for _, t in ipairs(room.observers) do
    local id, p = table.unpack(t)
    if id == self.id and room.room:hasObserver(p) then
      p:doNotify(command, jsonData)
    end
  end

  if room.notify_count >= room.notify_max and
    coroutine.status(room.main_co) == "normal" then
    room:delay(100)
  end
end

-- FIXME: 基本都改成新写法后删了这个兼容玩意
function ServerPlayer:__index(k)
  local request = self.room.last_request
  if not request then return nil end
  if k == "client_reply" then
    return request.result[self.id]
  elseif k == "reply_ready" then
    return request.result[self.id] and request.result[self.id] ~= ""
  end
end

--- 发送一句聊天
---@param msg string
function ServerPlayer:chat(msg)
  self.room:doBroadcastNotify("Chat", json.encode {
    type = 2,
    sender = self.id,
    msg = msg,
  })
end

function ServerPlayer:toJsonObject()
  local o = Player.toJsonObject(self)
  local sp = self._splayer
  o.setup_data = {
    self.id,
    sp:getScreenName(),
    sp:getAvatar(),
    false,
    sp:getTotalGameTime(),
  }
  return o
end

-- 似乎没有必要
-- function ServerPlayer:loadJsonObject() end

function ServerPlayer:reconnect()
  local room = self.room
  self.serverplayer:setState(fk.Player_Online)

  local summary = room:toJsonObject(self)
  self:doNotify("Reconnect", json.encode(summary))
  room:notifyProperty(self, self, "role")
  self:doNotify("RoomOwner", json.encode{ room.room:getOwner():getId() })

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

---@param cards integer|integer[]|Card|Card[]
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

  GameEvent.Phase:create(self, self.phase):exec()

  return false
end

---@param phase Phase
---@param delay? boolean
function ServerPlayer:gainAnExtraPhase(phase, delay)
  local room = self.room
  delay = (delay == nil) and true or delay
  local logic = room.logic
  if delay then
    local turn = logic:getCurrentEvent():findParent(GameEvent.Phase, true)
    if turn then
      turn:prependExitFunc(function() self:gainAnExtraPhase(phase, false) end)
      return
    end
  end

  local current = self.phase

  local phase_change = {
    from = current,
    to = phase
  }

  local skip = logic:trigger(fk.EventPhaseChanging, self, phase_change)

  phase = phase_change.to
  self.phase = phase
  room:broadcastProperty(self, "phase")

  local cancel_skip = true
  if phase ~= Player.NotActive and (skip) then
    cancel_skip = logic:trigger(fk.EventPhaseSkipping, self, phase)
  end
  if (not skip) or (cancel_skip) then
    room:sendLog{
      type = "#GainAnExtraPhase",
      from = self.id,
      arg = Util.PhaseStrMapper(phase),
    }

    GameEvent.Phase:create(self, self.phase):exec()

    phase_change = {
      from = phase,
      to = current
    }
    logic:trigger(fk.EventPhaseChanging, self, phase_change)
  else
    room:sendLog{
      type = "#PhaseSkipped",
      from = self.id,
      arg = Util.PhaseStrMapper(phase),
    }
    logic:trigger(fk.EventPhaseSkipped, self, phase)
  end

  self.phase = current
  room:broadcastProperty(self, "phase")
end

---@param phase_table? Phase[]
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
    if self.dead or room:getTag("endTurn") or phases[i] == nil then
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
      cancel_skip = logic:trigger(fk.EventPhaseSkipping, self, self.phase)
    end

    if (not skip) or (cancel_skip) then
      GameEvent.Phase:create(self, self.phase):exec()
    else
      room:sendLog{
        type = "#PhaseSkipped",
        from = self.id,
        arg = Util.PhaseStrMapper(self.phase),
      }
      logic:trigger(fk.EventPhaseSkipped, self, self.phase)
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
  if self.phase == Player.Play then
    self._phase_end = true
  end
  -- TODO: send log
end

--- 结束当前阶段。
function ServerPlayer:endCurrentPhase()
  self._phase_end = true
end

--- 获得一个额外回合
---@param delay? boolean
---@param skillName? string
function ServerPlayer:gainAnExtraTurn(delay, skillName)
  local room = self.room
  delay = (delay == nil) and true or delay
  skillName = (skillName == nil) and room.logic:getCurrentSkillName() or skillName
  if delay then
    local logic = room.logic
    local turn = logic:getCurrentEvent():findParent(GameEvent.Turn, true)
    if turn then
      turn:prependExitFunc(function() self:gainAnExtraTurn(false, skillName) end)
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
  table.insert(ex_tag, skillName)

  GameEvent.Turn:create(self):exec()

  table.remove(ex_tag)

  room.current = current
end

--- 当前是否处于额外的回合。
--- @return boolean
function ServerPlayer:insideExtraTurn()
  return self.tag["_extra_turn_count"] and #self.tag["_extra_turn_count"] > 0
end

--- 当前额外回合的技能原因。
---@return string
function ServerPlayer:getCurrentExtraTurnReason()
  local ex_tag = self.tag["_extra_turn_count"]
  if (not ex_tag) or #ex_tag == 0 then
    return "game_rule"
  end
  return ex_tag[#ex_tag]
end

--- 角色摸牌。
---@param num integer @ 摸牌数
---@param skillName? string @ 技能名
---@param fromPlace? string @ 摸牌的位置，"top" 或者 "bottom"
---@param moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@return integer[] @ 摸到的牌
function ServerPlayer:drawCards(num, skillName, fromPlace, moveMark)
  return self.room:drawCards(self, num, skillName, fromPlace, moveMark)
end

---@param pile_name string
---@param card integer | integer[] | Card | Card[]
---@param visible? boolean
---@param skillName? string
---@param proposer? integer
---@param visiblePlayers? integer | integer[] @ 为nil时默认对自己可见
function ServerPlayer:addToPile(pile_name, card, visible, skillName, proposer, visiblePlayers)
  self.room:moveCardTo(card, Card.PlayerSpecial, self, fk.ReasonJustMove, skillName, pile_name, visible,
  proposer or self.id, nil, visiblePlayers)
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
  self:removeVirtualEquip(card:getEffectiveId())
  Player.addVirtualEquip(self, card)
  self.room:doBroadcastNotify("AddVirtualEquip", json.encode{
    player = self.id,
    name = card.name,
    subcards = card.subcards,
  })
end

function ServerPlayer:removeVirtualEquip(cid)
  local ret = Player.removeVirtualEquip(self, cid)
  if ret then
    self.room:doBroadcastNotify("RemoveVirtualEquip", json.encode{
      player = self.id,
      id = cid,
    })
  end
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
---@param tos ServerPlayer[]
---@param skillName string
---@param initialCard? Card
---@return PindianStruct
function ServerPlayer:pindian(tos, skillName, initialCard)
  local pindianData = { from = self, tos = tos, reason = skillName, fromCard = initialCard, results = {} }
  self.room:pindian(pindianData)
  return pindianData
end

--- 播放技能的语音。
---@param skill_name string @ 技能名
---@param index? integer @ 语音编号，默认为-1（也就是随机播放）
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

---@param skill Skill | string
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

---@param skill Skill | string
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

---@param skill Skill | string
function ServerPlayer:isFakeSkill(skill)
  if type(skill) == "string" then skill = Fk.skills[skill] end
  assert(skill:isInstanceOf(Skill))
  return table.contains(self._fake_skills, skill)
end

---@param skill string | Skill
---@param isPrelight? boolean
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

---@param isDeputy? boolean
---@param no_trigger? boolean
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
  for _, s in ipairs(general:getSkillNameList(true)) do
    local skill = Fk.skills[s]
    self:loseFakeSkill(skill)
  end

  local ret = true
  if not ((isDeputy and self.general ~= "anjiang") or (not isDeputy and self.deputyGeneral ~= "anjiang")) then
    local other = Fk.generals[self:getMark(isDeputy and "__heg_general" or "__heg_deputy")] or Fk.generals["blank_shibing"]
    for _, sname in ipairs(other:getSkillNameList(true)) do
      local s = Fk.skills[sname]
      if s.frequency == Skill.Compulsory and s.relate_to_place ~= (isDeputy and "m" or "d") then
        ret = false
        break
      end
    end
  end
  if ret then
    self:loseFakeSkill("reveal_skill&")
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

  local data = {[isDeputy and "d" or "m"] = generalName}
  room.logic:trigger(fk.GeneralShown, self, data)
  if not no_trigger then
    local current_event = room.logic:getCurrentEvent()
    if table.contains({GameEvent.Round, GameEvent.Turn, GameEvent.Phase}, current_event.event) then
      room.logic:trigger(fk.GeneralRevealed, self, data)
    else
      if current_event.parent then
        repeat
          if table.contains({GameEvent.Round, GameEvent.Turn, GameEvent.Phase}, current_event.parent.event) then break end
          current_event = current_event.parent
        until (not current_event.parent)
      end
      current_event:addExitFunc(function ()
        room.logic:trigger(fk.GeneralRevealed, self, data)
      end)
    end
  end
end

function ServerPlayer:revealGenerals()
  self:revealGeneral(false, true)
  self:revealGeneral(true, true)
  local room = self.room
  local current_event = room.logic:getCurrentEvent()
  local data = {["m"] = self:getMark("__heg_general"), ["d"] = self:getMark("__heg_deputy")}
  if table.contains({GameEvent.Round, GameEvent.Turn, GameEvent.Phase}, current_event.event) then
    room.logic:trigger(fk.GeneralRevealed, self, data)
  else
    if current_event.parent then
      repeat
        if table.contains({GameEvent.Round, GameEvent.Turn, GameEvent.Phase}, current_event.parent.event) then break end
        current_event = current_event.parent
      until (not current_event.parent)
    end
    current_event:addExitFunc(function ()
      room.logic:trigger(fk.GeneralRevealed, self, data)
    end)
  end
end

function ServerPlayer:revealBySkillName(skill_name)
  local main = self.general == "anjiang"
  local deputy = self.deputyGeneral == "anjiang"

  if main then
    if table.contains(Fk.generals[self:getMark("__heg_general")]
      :getSkillNameList(true), skill_name) then
      self:revealGeneral(false)
      return
    end
  end

  if deputy then
    if table.contains(Fk.generals[self:getMark("__heg_deputy")]
      :getSkillNameList(true), skill_name) then
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
  local place = isDeputy and "m" or "d"
  for _, sname in ipairs(general:getSkillNameList()) do
    room:handleAddLoseSkills(self, "-" .. sname, nil, false, true)
    local s = Fk.skills[sname]
    if s.relate_to_place ~= place then
      if s.frequency == Skill.Compulsory then
        self:addFakeSkill("reveal_skill&")
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
  self.room:doBroadcastNotify("AddBuddy", json.encode{ self.id, other.id })
end

function ServerPlayer:removeBuddy(other)
  if type(other) == "number" then
    other = self.room:getPlayerById(other)
  end
  Player.removeBuddy(self, other)
  self.room:doBroadcastNotify("RmBuddy", json.encode{ self.id, other.id })
end

return ServerPlayer
