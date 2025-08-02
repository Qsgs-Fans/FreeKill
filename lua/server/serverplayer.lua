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
---@field public phase_state table[]
---@field public phase_index integer
---@field private _manually_fake_skills Skill[]
---@field public prelighted_skills Skill[]
---@field private _timewaste_count integer
---@field public ai SmartAI
---@field public ai_data any
local ServerPlayer = Player:subclass("ServerPlayer")

function ServerPlayer:initialize(_self)
  Player.initialize(self)
  self.serverplayer = _self -- 控制者
  self._splayer = _self -- 真正在玩的玩家
  self._observers = { _self } -- "旁观"中的玩家，然而不包括真正的旁观者
  self.id = _self:getId()
  self.room = nil

  self.phases = {}
  self.phase_state = {}

  self._manually_fake_skills = {}
  self.prelighted_skills = {}
  self._prelighted_skills = {}

  self._timewaste_count = 0
  self.ai = SmartAI:new(self)
end

---@param command string
---@param data any
function ServerPlayer:doNotify(command, data)
  if type(data) == "string" then
    local err, dat = pcall(json.decode, data)
    if err ~= false then
      fk.qWarning("Don't use json.encode. Pass value directly to ServerPlayer:doNotify.\n"..debug.traceback())
      data = dat
    end
  end

  local cbordata = cbor.encode(data)

  local room = self.room
  for _, p in ipairs(self._observers) do
    if p:getState() ~= fk.Player_Robot then
      room.notify_count = room.notify_count + 1
      p:doNotify(command, cbordata)
    end
  end

  for _, t in ipairs(room.observers) do
    local id, p = table.unpack(t)
    if id == self.id and room.room:hasObserver(p) and p:getState() ~= fk.Player_Robot then
      p:doNotify(command, cbordata)
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

-- FIXME: 理由同上，垃圾request体系赶紧狠狠重构
function ServerPlayer:__newindex(k, v)
  if k == "client_reply" then
    local request = self.room.last_request
    if not request then return end
    request.result[self.id] = v
    return
  elseif k == "reply_ready" then
    return
  end
  rawset(self, k, v)
end

--- 发送一句聊天
---@param msg string
function ServerPlayer:chat(msg)
  self.room:doBroadcastNotify("Chat", {
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

  local summary = room:toJsonObject(self)
  self:doNotify("Reconnect", summary)
  self:doNotify("RoomOwner", { room.room:getOwner():getId() })

  -- send fake skills
  for _, s in ipairs(self._manually_fake_skills) do
    self:doNotify("AddSkill", { self.id, s.name, true })
    if table.contains(self.prelighted_skills, s) then
      self:doNotify("PrelightSkill", { s.name, true })
    end
  end

  for _, skills in ipairs(room.status_skills) do
    for _, skill in ipairs(skills) do
      self:doNotify("AddStatusSkill", { skill.name })
    end
  end

  room:broadcastProperty(self, "state")
end

--- 翻面
---@param data any? 额外数据
---@return boolean @ 是否成功翻面
function ServerPlayer:turnOver(data)
  if data == nil then
    data = {
      who = self,
      reason = self.room.logic:getCurrentSkillName() or "game_rule",
    }
  end

  self.room.logic:trigger(fk.BeforeTurnOver, self, data)

  if data.prevented then
    return false
  end

  self.faceup = not self.faceup
  self.room:broadcastProperty(self, "faceup")

  self.room:sendLog{
    type = "#TurnOver",
    from = self.id,
    arg = self.faceup and "face_up" or "face_down",
  }

  self.room.logic:trigger(fk.TurnedOver, self, data)
  return true
end

--- 令一名角色展示一些牌
---
--- 因为要过锁视技，最好不要展示不属于你的牌
---@param cards integer|integer[]|Card|Card[]
function ServerPlayer:showCards(cards)
  cards = Card:getIdList(cards)
  for _, id in ipairs(cards) do
    Fk:filterCard(id, self)
  end

  local room = self.room
  -- room:sendLog{
  --   type = "#ShowCard",
  --   from = self.id,
  --   card = cards,
  -- }
  -- room:doBroadcastNotify("ShowCard", {
  --   from = self.id,
  --   cards = cards,
  -- })
  -- room:sendFootnote(cards, {
  --   type = "##ShowCard",
  --   from = self.id,
  -- })
  self.room:showCards(cards, self)
end


--获得一个额外阶段
---@param phase Phase
---@param skillName? string @ 额外阶段原因
---@param delay? boolean
---@param extra_data? table @ 额外信息（@寤寐）
function ServerPlayer:gainAnExtraPhase(phase, skillName, delay, extra_data)
  local room = self.room
  delay = (delay == nil) and true or delay
  local logic = room.logic
  if delay then
    local turn = logic:getCurrentEvent():findParent(GameEvent.Turn, true)
    if turn then
      turn.data:gainAnExtraPhase(phase, skillName, self, extra_data)
      return
    end
  end

  local current = self.phase

  self.phase = Player.PhaseNone
  room:broadcastProperty(self, "phase")

  local data = { ---@type PhaseDataSpec
    who = self,
    reason = skillName or "game_rule",
    phase = phase,
    extra_data = extra_data,
  }
  GameEvent.Phase:create(PhaseData:new(data)):exec()

  self.phase = current
  room:broadcastProperty(self, "phase")
end

--- 跳过本回合的某个阶段
---@param phase Phase
function ServerPlayer:skip(phase)
  local room = self.room
  local current_turn = room.logic:getCurrentEvent():findParent(GameEvent.Turn, true)
  if current_turn then
    local phase_data
    for i = current_turn.data.phase_index + 1, #current_turn.data.phase_table, 1 do
      phase_data = current_turn.data.phase_table[i]
      if phase_data.phase == phase then
        phase_data.skipped = true
      end
    end
  end
end

--- 判断该角色是否拥有能跳过的阶段
---@param phase Phase
---@return boolean
function ServerPlayer:canSkip(phase)
  local room = self.room
  local current_turn = room.logic:getCurrentEvent():findParent(GameEvent.Turn, true)
  if current_turn then
    local phase_data
    for i = current_turn.data.phase_index + 1, #current_turn.data.phase_table, 1 do
      phase_data = current_turn.data.phase_table[i]
      if phase_data.phase == phase and not phase_data.skipped then
        return true
      end
    end
  end
  return false
end

--- 当进行到出牌阶段空闲点时，结束出牌阶段。
function ServerPlayer:endPlayPhase()
  if self.phase == Player.Play then
    self:endCurrentPhase()
  end
  -- TODO: send log
end

--- 结束当前阶段。
function ServerPlayer:endCurrentPhase()
  local room = self.room
  local current_phase = room.logic:getCurrentEvent():findParent(GameEvent.Phase, true)
  if current_phase then
    current_phase.data.phase_end = true
  end
end

--- 获得一个额外回合
---@param delay? boolean @ 是否延迟到当前回合结束再开启额外回合，默认是
---@param skillName? string @ 额外回合原因
---@param phases? Phase[] @ 此额外回合进行的额定阶段列表
---@param extra_data? table @ 额外数据
function ServerPlayer:gainAnExtraTurn(delay, skillName, phases, extra_data)
  local room = self.room
  delay = (delay == nil) and true or delay
  skillName = skillName or room.logic:getCurrentSkillName() or "game_rule"
  if delay then
    table.insert(room.extra_turn_list, 1, {who = self, reason = skillName, phases = phases, extra_data = extra_data})
    return
  end


  local current = room.current
  room:setCurrent(self)

  room:addTableMark(self, "_extra_turn_count", skillName)

  local turn_data = TurnData:new(self, skillName, phases)
  turn_data.extra_data = extra_data

  GameEvent.Turn:create(turn_data):exec()

  local mark = self:getTableMark("_extra_turn_count")
  if #mark > 0 then
    table.remove(mark)
    room:setPlayerMark(self, "_extra_turn_count", mark)
  end

  room:setCurrent(current)
end

--- 当前是否处于额外的回合。
--- @return boolean
function ServerPlayer:insideExtraTurn()
  return self:getCurrentExtraTurnReason() ~= "game_rule"
end

--- 当前额外回合的技能原因。非额外回合则为game_rule
---@return string
function ServerPlayer:getCurrentExtraTurnReason()
  local mark = self:getTableMark("_extra_turn_count")
  return mark[#mark] or "game_rule"
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

--- 将一些牌加入私人牌堆
---@param pile_name string
---@param card integer | integer[] | Card | Card[]
---@param visible? boolean
---@param skillName? string
---@param proposer? ServerPlayer
---@param visiblePlayers? ServerPlayer | ServerPlayer[] @ 为nil时默认对自己可见
function ServerPlayer:addToPile(pile_name, card, visible, skillName, proposer, visiblePlayers)
  self.room:moveCardTo(card, Card.PlayerSpecial, self, fk.ReasonJustMove, skillName, pile_name, visible,
  proposer or self, nil, visiblePlayers)
end

function ServerPlayer:bury()
  self:onAllSkillLose()
  self:setCardUseHistory("")
  self:setSkillUseHistory("")
  self:throwAllCards()
  self:throwAllMarks()
  self:clearPiles()
  self:reset()
end

function ServerPlayer:throwAllCards(flag, skillName)
  local cardIds = {}
  flag = flag or "hej"
  skillName = skillName or "game_rule"
  if string.find(flag, "h") then
    table.insertTable(cardIds, self.player_cards[Player.Hand])
  end

  if string.find(flag, "e") then
    table.insertTable(cardIds, self.player_cards[Player.Equip])
  end

  if string.find(flag, "j") then
    table.insertTable(cardIds, self.player_cards[Player.Judge])
  end

  if not self.dead then
    cardIds = table.filter(cardIds, function (id)
      return not self:prohibitDiscard(id)
    end)
  end
  if #cardIds > 0 then
    self.room:throwCard(cardIds, skillName, self)
  end
end

function ServerPlayer:onAllSkillLose()
  for _, skill in ipairs(self:getAllSkills()) do
    skill:getSkeleton():onLose(self, true)
  end
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
  self.room:doBroadcastNotify("AddVirtualEquip", {
    player = self.id,
    name = card.name,
    subcards = card.subcards,
  })
end

function ServerPlayer:removeVirtualEquip(cid)
  local ret = Player.removeVirtualEquip(self, cid)
  if ret then
    self.room:doBroadcastNotify("RemoveVirtualEquip", {
      player = self.id,
      id = cid,
    })
  end
  return ret
end

--- 增加卡牌使用次数
function ServerPlayer:addCardUseHistory(cardName, num)
  Player.addCardUseHistory(self, cardName, num)
  self.room:doBroadcastNotify("AddCardUseHistory", {self.id, cardName, num})
end

--- 设置卡牌已使用次数
function ServerPlayer:setCardUseHistory(cardName, num, scope)
  Player.setCardUseHistory(self, cardName, num, scope)
  self.room:doBroadcastNotify("SetCardUseHistory", {self.id, cardName, num, scope})
end

-- 增加技能发动次数
function ServerPlayer:addSkillUseHistory(skillName, num)
  Player.addSkillUseHistory(self, skillName, num)
  self.room:doBroadcastNotify("AddSkillUseHistory", {self.id, skillName, num})
end

-- 设置技能已发动次数
function ServerPlayer:setSkillUseHistory(skillName, num, scope)
  Player.setSkillUseHistory(self, skillName, num, scope)
  self.room:doBroadcastNotify("SetSkillUseHistory", {self.id, skillName, num, scope})
end

--- 设置连环状态
---@param chained boolean @ true为横置，false为重置
---@param data any? @ 额外数据
---@return boolean @ 是否成功横置或重置
function ServerPlayer:setChainState(chained, data)
  local room = self.room
  if data == nil then
    data = {
      who = self,
      reason = self.room.logic:getCurrentSkillName() or "game_rule",
    }
  end

  room.logic:trigger(fk.BeforeChainStateChange, self, data)
  if data.prevented then
    return false
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
  room.logic:trigger(fk.ChainStateChanged, self, data)
  return true
end

--- 复原武将牌（翻至正面、解除连环状态）
function ServerPlayer:reset()
  if self.faceup and not self.chained then return end
  self.room:sendLog{
    type = "#ChainStateChange",
    from = self.id,
    arg = "reset-general"
  }
  if self.dead then
    if self.chained then
      self.chained = false
      self.room:broadcastProperty(self, "chained")
    end
    if not self.faceup then
      self.faceup = true
      self.room:broadcastProperty(self, "faceup")
    end
  else
    if self.chained then
      self:setChainState(false)
    end
    if not self.faceup then
      if self.dead then
        self.faceup = true
        self.room:broadcastProperty(self, "faceup")
      else
        self:turnOver()
      end
    end
  end
end

--- 对若干名角色发起拼点。
---@param tos ServerPlayer[] @ 拼点目标角色
---@param skillName string @ 技能名
---@param initialCard? Card @ 发起者的起始拼点牌
---@return PindianData
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
  skill = Player.addFakeSkill(self, skill)
  if not skill then
    return
  end
  table.insertIfNeed(self._manually_fake_skills, skill)

  -- TODO
  self:doNotify("AddSkill", { self.id, skill.name, true })
end

---@param skill Skill | string
function ServerPlayer:loseFakeSkill(skill)
  skill = Player.loseFakeSkill(self, skill)
  if not skill then
    return
  end
  table.removeOne(self._manually_fake_skills, skill)

  -- TODO
  self:doNotify("LoseSkill", { self.id, skill.name, true })
end

---@param skill string | Skill
---@param isPrelight? boolean
function ServerPlayer:prelightSkill(skill, isPrelight)
  if type(skill) == "string" then skill = Fk.skills[skill] end
  assert(skill:isInstanceOf(Skill))

  if not self._prelighted_skills[skill] and not self:hasSkill(skill) then
    self._prelighted_skills[skill] = true
    -- to attach skill to room
    self.room:addSkill(skill)
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

  self:doNotify("PrelightSkill", { skill.name, isPrelight })
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
  local tolose = {}
  for _, s in ipairs(general:getSkillNameList(true)) do
    local skill = Fk.skills[s]
    if self:isFakeSkill(skill) then
      self:loseFakeSkill(skill)
    else
      table.insert(tolose, skill.name)
    end
  end

  local ret = true
  if not ((isDeputy and self.general ~= "anjiang") or (not isDeputy and self.deputyGeneral ~= "anjiang")) then
    local other = Fk.generals[self:getMark(isDeputy and "__heg_general" or "__heg_deputy")] or Fk.generals["blank_shibing"]
    for _, sname in ipairs(other:getSkillNameList(true)) do
      local s = Fk.skills[sname]
      if s:hasTag(Skill.Compulsory) and not s:hasTag(isDeputy and Skill.DeputyPlace or Skill.MainPlace) and self:isFakeSkill(s) then
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
  if #tolose > 0 then
    room:handleAddLoseSkills(self, "-"..table.concat(tolose, "|-"), nil, false)
  end
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
  room.logic:trigger(fk.GeneralShown, self, data) -- 注意不应该使用这个时机发动技能
  if not no_trigger then
    local current_event = room.logic:getCurrentEvent()
    if table.contains({GameEvent.Game, GameEvent.Round, GameEvent.Turn, GameEvent.Phase}, current_event.event) then
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

  room:setPlayerMark(self, mark, generalName)

  if isDeputy then
    room:setDeputyGeneral(self, "anjiang")
    room:broadcastProperty(self, "deputyGeneral")
  else
    room:setPlayerGeneral(self, "anjiang", false)
    room:broadcastProperty(self, "general")
  end

  local general = Fk.generals[generalName]
  local place = isDeputy and Skill.MainPlace or Skill.DeputyPlace
  for _, sname in ipairs(general:getSkillNameList()) do
    if self:hasSkill(sname, true, true) then
      room:handleAddLoseSkills(self, "-" .. sname, nil, false, false)
      local s = Fk.skills[sname]
      if not s:hasTag(place) then
        if s:hasTag(Skill.Compulsory) then
          self:addFakeSkill("reveal_skill&")
        end
        self:addFakeSkill(s)
      end
    end
  end

  self.gender = General.Agender
  if Fk.generals[self.general].gender ~= General.Agender then
    self.gender = Fk.generals[self.general].gender
  elseif self.deputyGeneral and self.deputyGeneral ~= "" and Fk.generals[self.deputyGeneral].gender ~= General.Agender then
    self.gender = Fk.generals[self.deputyGeneral].gender
  end
  room:broadcastProperty(self, "gender")

  room.logic:trigger(fk.GeneralHidden, self, generalName)
end

--- 是否为友方
---@param to ServerPlayer @ 待判断的角色
---@return boolean
function ServerPlayer:isFriend(to)
  return Fk.game_modes[self.room.settings.gameMode]:friendEnemyJudge(self, to)
end

--- 是否为敌方
---@param to ServerPlayer @ 待判断的角色
---@return boolean
function ServerPlayer:isEnemy(to)
  return not Fk.game_modes[self.room.settings.gameMode]:friendEnemyJudge(self, to)
end

--- 获得队友
---@param include_self? boolean @ 是否包括自己。默认是
---@param include_dead? boolean @ 是否包括死亡角色。默认否
---@return ServerPlayer[]
function ServerPlayer:getFriends(include_self, include_dead)
  if include_self == nil then include_self = true end
  local players = include_dead and self.room.players or self.room.alive_players
  local friends = table.filter(players, function (p)
    return self:isFriend(p)
  end)
  if not include_self then
    table.removeOne(friends, self)
  end
  return friends
end

--- 获得敌人
---@param include_dead? boolean @ 是否包括死亡角色。默认否
---@return ServerPlayer[]
function ServerPlayer:getEnemies(include_dead)
  local players = include_dead and self.room.players or self.room.alive_players
  local enemies = table.filter(players, function (p)
    return self:isEnemy(p)
  end)
  return enemies
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
  self.room:doBroadcastNotify("AddBuddy", { self.id, other.id })
end

function ServerPlayer:removeBuddy(other)
  if type(other) == "number" then
    other = self.room:getPlayerById(other)
  end
  Player.removeBuddy(self, other)
  self.room:doBroadcastNotify("RmBuddy", { self.id, other.id })
end

-- 青釭剑

---类〖青釭剑〗的无视防具效果（注意仅能在onAim的四个时机中使用）
---@param data AimData
function ServerPlayer:addQinggangTag(data)
  self.room:addSkill("#qinggang_sword_skill")
  if not data.qinggang_used then
    data.qinggang_used = true
    self.room:addPlayerMark(self, MarkEnum.MarkArmorNullified)
    data.extra_data = data.extra_data or {}
    data.extra_data.qinggang_tag = data.extra_data.qinggang_tag or {}
    table.insert(data.extra_data.qinggang_tag, data.to.id)
  end
end

return ServerPlayer
