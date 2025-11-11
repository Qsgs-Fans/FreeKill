-- SPDX-License-Identifier: GPL-3.0-or-later

---@class Client : AbstractRoom, ClientBase
Client = AbstractRoom:subclass('Client')

-- 此为勾式的手写泛型. 本意是extends AbstractRoom<Player>
---@class Client
---@field public players ClientPlayer[]
---@field public alive_players ClientPlayer[] @ 所有存活玩家的数组
---@field public observers ClientPlayer[]
---@field public current ClientPlayer
---@field public getPlayerById fun(self: AbstractRoom, id: integer): ClientPlayer
---@field public getPlayerBySeat fun(self: AbstractRoom, seat: integer): ClientPlayer
---@field public setCurrent fun(self: AbstractRoom, p: ClientPlayer)
---@field public getCurrent fun(self: AbstractRoom): ClientPlayer

-- load client classes
ClientPlayer = require "lunarltk.client.clientplayer"

local ClientBase = Fk.Base.ClientBase
Client:include(ClientBase)

function Client:initialize(_client)
  AbstractRoom.initialize(self)
  ClientBase.initialize(self, _client)

  self.clientplayer_klass = ClientPlayer

  self:addCallback("SetCardFootnote", self.setCardFootnote)
  self:addCallback("PlayCard", self.playCard)
  self:addCallback("AskForCardChosen", self.askForCardChosen)
  self:addCallback("MoveCards", self.moveCards)
  self:addCallback("ShowCard", self.showCard)
  self:addCallback("LoseSkill", self.loseSkill)
  self:addCallback("AddSkill", self.addSkill)
  self:addCallback("AddStatusSkill", self.addStatusSkill)
  self:addCallback("AskForSkillInvoke", self.askForSkillInvoke)
  self:addCallback("AskForUseActiveSkill", self.askForUseActiveSkill)
  self:addCallback("AskForUseCard", self.askForUseCard)
  self:addCallback("AskForResponseCard", self.askForResponseCard)
  self:addCallback("SetCurrent", self.handleSetCurrent)
  self:addCallback("SetCardMark", self.setCardMark)
  self:addCallback("LogEvent", self.logEvent)
  self:addCallback("AddCardUseHistory", self.addCardUseHistory)
  self:addCallback("SetCardUseHistory", self.setCardUseHistory)
  self:addCallback("AddSkillUseHistory", self.addSkillUseHistory)
  self:addCallback("AddSkillBranchUseHistory", self.addSkillBranchUseHistory)
  self:addCallback("SetSkillUseHistory", self.setSkillUseHistory)
  self:addCallback("SetSkillBranchUseHistory", self.setSkillBranchUseHistory)
  self:addCallback("AddVirtualEquip", self.addVirtualEquip)
  self:addCallback("RemoveVirtualEquip", self.removeVirtualEquip)
  self:addCallback("ChangeSelf", self.changeSelf)
  self:addCallback("UpdateQuestSkillUI", self.updateQuestSkillUI)
  self:addCallback("UpdateMarkArea", self.UpdateMarkArea)
  self:addCallback("PrintCard", self.handlePrintCard)
  self:addCallback("AddBuddy", self.addBuddy)
  self:addCallback("RmBuddy", self.rmBuddy)
  self:addCallback("PrepareDrawPile", self.prepareDrawPile)
  self:addCallback("ShuffleDrawPile", self.handleShuffleDrawPile)
  self:addCallback("SyncDrawPile", self.syncDrawPile)
  self:addCallback("ChangeCardArea", self.handleChangeCardArea)
  self:addCallback("SetPlayerPile", self.setPlayerPile)
  self:addCallback("FilterCard", self.handleFilterCard)
  self:addCallback("ShowVirtualCard", self.showVirtualCard)
  self:addCallback("ChangeSkin", self.changeSkin)

  self.disabled_packs = {}
  self.disabled_generals = {}
end

function Client:enterRoom(_data)
  ClientBase.enterRoom(self, _data)
  self = ClientInstance

  local data = _data[3]
  table.insertTableIfNeed(
    data.disabledPack,
    Fk.game_mode_disabled[data.gameMode] or Util.DummyTable
  )
  self.disabled_packs = data.disabledPack
  self.disabled_generals = data.disabledGenerals
end

function Client:startGame()
  self.alive_players = table.simpleClone(self.players)
  ClientBase.startGame(self)
end

---@param msg LogMessage
function Client:parseMsg(msg, nocolor, visible_data)
  local data = msg
  local function getPlayerStr(pid, color)
    if nocolor then color = "white" end
    if not pid then
      return ""
    end
    local p = self:getPlayerById(pid)
    local str = '<font color="%s"><b>%s</b></font>'
    if p.general == "anjiang" and (p.deputyGeneral == "anjiang"
      or not p.deputyGeneral) then
      local ret = Fk:translate("seat#" .. p.seat)
      if pid == Self.id then
        ret = ret .. Fk:translate("playerstr_self")
      end
      return string.format(str, color, ret)
    end

    local ret = p.general
    ret = Fk:translate(ret)
    if p.deputyGeneral and p.deputyGeneral ~= "" then
      ret = ret .. "/" .. Fk:translate(p.deputyGeneral)
    end
    for _, p2 in ipairs(Fk:currentRoom().players) do
      if p2 ~= p and p2.general == p.general and p2.deputyGeneral == p.deputyGeneral then
        ret = ret .. ("[%d]"):format(p.seat)
        break
      end
    end
    if pid == Self.id then
      ret = ret .. Fk:translate("playerstr_self")
    end
    ret = string.format(str, color, ret)
    return ret
  end

  local from = getPlayerStr(data.from, "#0C8F0C")

  ---@type any
  local to = data.to or Util.DummyTable
  local to_str = {}
  for _, id in ipairs(to) do
    table.insert(to_str, getPlayerStr(id, "#CC3131"))
  end
  to = table.concat(to_str, ", ")

  ---@type any
  local card = data.card or Util.DummyTable
  local allUnknown = true
  local unknownCount = 0
  for _, id in ipairs(card) do
    if type(id) == "table" then id = id:getEffectiveId() end
    local known = id ~= -1
    if visible_data then known = visible_data[tostring(id)] end
    if known then
      allUnknown = false
    else
      unknownCount = unknownCount + 1
    end
  end

  if allUnknown then
    card = Fk:translate("unknown_card")
  else
    local card_str = {}
    for _, id in ipairs(card) do
      local cid = id
      if type(id) == "table" then cid = id:getEffectiveId() end
      local known = cid ~= -1
      if visible_data then known = visible_data[tostring(cid)] end
      if known then
        if type(id) == "table" then
          table.insert(card_str, id:toLogString())
        else
          table.insert(card_str, Fk:getCardById(cid, true):toLogString())
        end
      end
    end
    if unknownCount > 0 then
      local suffix = unknownCount > 1 and ("x" .. unknownCount) or ""
      table.insert(card_str, Fk:translate("unknown_card") .. suffix)
    end
    card = table.concat(card_str, ", ")
  end

  local function parseArg(arg)
    arg = arg == nil and "" or arg
    local noneedcolor
    if type(arg) == "string" then
      arg = Fk:translate(arg)
    elseif type(arg) == "table" then
      if not arg.class then
        arg = json.encode(arg)
      else
        arg = arg.__touistring and arg:__touistring() or arg
        noneedcolor = true
      end
    else
      arg = tostring(arg)
    end
    if not noneedcolor then
      arg = string.format('<font color="%s"><b>%s</b></font>', nocolor and "white" or "#0598BC", arg)
    end
    return arg
  end

  local log = Fk:translate(data.type)
  log = string.gsub(log, "%%from", from)
  log = string.gsub(log, "%%to", to)
  log = string.gsub(log, "%%card", card)

  for i = 2, 9 do
    local v = data["arg" .. i]
    if v == nil then break end
    local arg = parseArg(v)
    log = log:gsub("%%arg" .. i, arg)
  end

  local arg = parseArg(data.arg)
  log = string.gsub(log, "%%arg", arg)

  return log
end

---@param msg LogMessage
function Client:appendLog(msg, visible_data)
  local text = self:parseMsg(msg, nil, visible_data)
  self:notifyUI("GameLog", text)
  if msg.toast then
    self:notifyUI("ShowToast", text)
  end
end

---@param msg LogMessage
function Client:setCardNote(ids, msg, virtual)
  for _, id in ipairs(ids) do
    if id ~= -1 then
      self:notifyUI("SetCardFootnote", { id, self:parseMsg(msg, true), virtual })
    end
  end
end

function Client:setCardFootnote(data)
  self:setCardNote(table.unpack(data));
end

function Client:setPlayerProperty(player, property, value)
  ClientBase.setPlayerProperty(self, player, property, value)

  if property == "dead" then
    if value == true then
      table.removeOne(self.alive_players, player)
    else
      table.insertIfNeed(self.alive_players, player)
    end
  end
end

function Client:playCard(data)
  self:setupRequestHandler(Self, "PlayCard")
  self:notifyUI("PlayCard", data)
end

function Client:askForCardChosen(data)
  -- jsonData: [ int target_id, string flag, int reason ]
  local id, flag, reason, prompt = data[1], data[2], data[3], data[4]
  local target = self:getPlayerById(id)
  local hand = table.simpleClone(target.player_cards[Player.Hand])
  table.shuffle(hand)
  local equip = target.player_cards[Player.Equip]
  local judge = target.player_cards[Player.Judge]

  local ui_data = flag
  if type(flag) == "string" then
    if not string.find(flag, "h") then
      hand = {}
    end
    if not string.find(flag, "e") then
      equip = {}
    end
    if not string.find(flag, "j") then
      judge = {}
    end
    local visible_data = {}
    for _, cid in ipairs(table.connect(hand, judge)) do
      if not Self:cardVisible(cid) then
        visible_data[tostring(cid)] = false
      end
    end
    if next(visible_data) == nil then visible_data = nil end
    ui_data = {
      _id = id,
      _reason = reason,
      card_data = {},
      _prompt = prompt,
      visible_data = visible_data,
    }
    if #hand ~= 0 then table.insert(ui_data.card_data, { "$Hand", hand }) end
    if #equip ~= 0 then table.insert(ui_data.card_data, { "$Equip", equip }) end
    if #judge ~= 0 then table.insert(ui_data.card_data, { "$Judge", judge }) end
  else
    ui_data._id = id
    ui_data._reason = reason
    ui_data._prompt = prompt
  end
  self:notifyUI("AskForCardChosen", ui_data)
end

--- separated moves to many moves(one card per move)
---@param moves MoveCardsData[]
local function separateMoves(moves)
  local ret = {}  ---@type CardsMoveInfo[]
  for _, move in ipairs(moves) do
    for _, info in ipairs(move.moveInfo) do
      table.insert(ret, {
        ids = {info.cardId},
        from = move.from,
        to = move.to,
        toArea = move.toArea,
        fromArea = info.fromArea,
        moveReason = move.moveReason,
        specialName = move.specialName,
        fromSpecialName = info.fromSpecialName,
        proposer = move.proposer
      })
    end
  end
  return ret
end

--- merge separated moves that information is the same
local function mergeMoves(moves)
  local ret = {}
  local temp = {}
  for _, move in ipairs(moves) do
    local info = string.format("%q,%q,%q,%q,%s,%s,%q",
      move.from, move.to, move.fromArea, move.toArea,
      move.specialName, move.fromSpecialName, move.proposer)
    if temp[info] == nil then
      temp[info] = {
        ids = {},
        from = move.from,
        to = move.to,
        fromArea = move.fromArea,
        toArea = move.toArea,
        moveReason = move.moveReason,
        specialName = move.specialName,
        fromSpecialName = move.fromSpecialName,
        proposer = move.proposer,
      }
    end
    -- table.insert(temp[info].ids, move.moveVisible and move.ids[1] or -1)
    table.insert(temp[info].ids, move.ids[1])
  end
  for _, v in pairs(temp) do
    table.insert(ret, v)
  end
  return ret
end

local function sendMoveCardLog(move, visible_data)
  local client = ClientInstance ---@class Client
  if #move.ids == 0 then return end
  local hidden = not not table.find(move.ids, function(id)
    return visible_data[tostring(id)] == false
  end)
  local msgtype

  local logCards = move.ids
  -- 因为是先addVirtualEquip再发战报 所以只能从move.to拿
  if move.to and (move.toArea == Card.PlayerEquip or move.toArea == Card.PlayerJudge) then
    local vcard = client:getPlayerById(move.to):getVirtualEquip(move.ids[1])
    logCards = vcard and { vcard } or logCards
  end

  if move.toArea == Card.PlayerHand then
    if move.fromArea == Card.PlayerSpecial then
      client:appendLog({
        type = "$GetCardsFromPile",
        from = move.to,
        arg = move.fromSpecialName,
        arg2 = #move.ids,
        card = logCards,
      }, visible_data)
    elseif move.fromArea == Card.DrawPile then
      client:appendLog({
        type = "$DrawCards",
        from = move.to,
        card = logCards,
        arg = #move.ids,
      }, visible_data)
    elseif move.fromArea == Card.Processing then
      client:appendLog({
        type = "$GotCardBack",
        from = move.to,
        card = logCards,
        arg = #move.ids,
      }, visible_data)
    elseif move.fromArea == Card.DiscardPile then
      client:appendLog({
        type = "$RecycleCard",
        from = move.to,
        card = logCards,
        arg = #move.ids,
      }, visible_data)
    elseif move.from then
      client:appendLog({
        type = "$MoveCards",
        from = move.from,
        to = { move.to },
        arg = #move.ids,
        card = logCards,
      }, visible_data)
    else
      client:appendLog({
        type = "$PreyCardsFromPile",
        from = move.to,
        card = logCards,
        arg = #move.ids,
      }, visible_data)
    end
  elseif move.toArea == Card.PlayerEquip then
    if move.from ~= move.to and move.fromArea == Card.PlayerEquip then
      client:appendLog({
        type = "$LightningMove",
        from = move.from,
        to = { move.to },
        card = logCards,
      }, visible_data)
    else
      client:appendLog({
        type = "$InstallEquip",
        from = move.to,
        card = logCards,
      }, visible_data)
    end
  elseif move.toArea == Card.PlayerJudge then
    if move.from ~= move.to and move.fromArea == Card.PlayerJudge then
      client:appendLog({
        type = "$LightningMove",
        from = move.from,
        to = { move.to },
        card = logCards,
      }, visible_data)
    elseif move.from then
      client:appendLog({
        type = "$PasteCard",
        from = move.from,
        to = { move.to },
        card = logCards,
      }, visible_data)
    end
  elseif move.toArea == Card.PlayerSpecial then
    client:appendLog({
      type = "$AddToPile",
      arg = move.specialName,
      arg2 = #move.ids,
      from = move.to,
      card = logCards,
    }, visible_data)
  elseif move.fromArea == Card.PlayerEquip then
    client:appendLog({
      type = "$UninstallEquip",
      from = move.from,
      card = logCards,
    }, visible_data)
  elseif move.toArea == Card.Processing then
    if move.fromArea == Card.DrawPile and (move.moveReason == fk.ReasonPut or move.moveReason == fk.ReasonJustMove) then
      if hidden then
        client:appendLog({
          type = "$ViewCardFromDrawPile",
          from = move.proposer,
          arg = #move.ids,
        }, visible_data)
      else
        client:appendLog({
          type = "$TurnOverCardFromDrawPile",
          from = move.proposer,
          card = logCards,
          arg = #move.ids,
        }, visible_data)
        client:setCardNote(move.ids, {
          type = "$$TurnOverCard",
          from = move.proposer,
        })
      end
    end
  elseif move.from and move.toArea == Card.DrawPile then
    msgtype = hidden and "$PutCard" or "$PutKnownCard"
    client:appendLog({
      type = msgtype,
      from = move.from,
      card = logCards,
      arg = #move.ids,
    }, visible_data)
    client:setCardNote(move.ids, {
      type = "$$PutCard",
      from = move.from,
    })
  elseif move.toArea == Card.DiscardPile then
    if move.moveReason == fk.ReasonDiscard then
      if move.proposer and move.proposer ~= move.from then
        client:appendLog({
          type = "$DiscardOther",
          from = move.from,
          to = {move.proposer},
          card = logCards,
          arg = #move.ids,
        }, visible_data)
      else
        client:appendLog({
          type = "$DiscardCards",
          from = move.from,
          card = logCards,
          arg = #move.ids,
        }, visible_data)
      end
    elseif move.moveReason == fk.ReasonPutIntoDiscardPile then
      client:appendLog({
        type = "$PutToDiscard",
        card = logCards,
        arg = #move.ids,
      }, visible_data)
    end
  -- elseif move.toArea == Card.Void then
    -- nop
  end

  -- TODO: footnote
  if move.moveReason == fk.ReasonDiscard then
    client:setCardNote(move.ids, {
      type = "$$DiscardCards",
      from = move.from
    })
  end
end

function Client:moveCards(data)
  -- jsonData: CardsMoveStruct[]
  local raw_moves, event_id = table.unpack(data)
  for _, d in ipairs(raw_moves) do
    if #d.moveInfo > 0 then
      for _, info in ipairs(d.moveInfo) do
        self:applyMoveInfo(d, info)
        Fk:filterCard(info.cardId, self:getPlayerById(d.to))
      end
    end
  end

  local visible_data = {}
  for _, move in ipairs(raw_moves) do
    for _, info in ipairs(move.moveInfo) do
      local cid = info.cardId
      visible_data[tostring(cid)] = Self:cardVisible(cid, move)
    end
  end
  local separated = separateMoves(raw_moves)
  local merged = mergeMoves(separated)
  visible_data.merged = merged
  visible_data.event_id = event_id
  self:notifyUI("MoveCards", visible_data)
  for _, move in ipairs(merged) do
    sendMoveCardLog(move, visible_data)
  end
end

function Client:showCard(data)
  -- local from = data.from
  --[[
  local cards = data.cards
  local merged = {
    {
      ids = cards,
      fromArea = Card.DrawPile,
      toArea = Card.Processing,
    }
  }
  local vdata = {}
  for _, id in ipairs(cards) do
    vdata[tostring(id)] = true
  end
  vdata.merged = merged
  vdata.event_id = 0
  self:notifyUI("MoveCards", vdata)
  --]]
  local cards, src, event_id = data[1], data[2], data[3]
  local fakeCards = table.map(cards, function(cid)
    local c = Fk:getCardById(cid, true)
    local fake = Fk:cloneCard(c.name, c.suit, c.number)
    for name, v in pairs(self.card_marks[cid] or Util.DummyTable) do
      if name:find("-public", 1, true) then
        fake:setMark(name, v)
      end
    end
    return fake
  end)
  local msg = {
    type = "##ShowCard",
    from = src,
  }
  src = src or 0
  self:showVirtualCard({ fakeCards, src, msg, event_id })
end


-- 更新限定技，觉醒技、转换技、使命技在武将牌旁边的技能UI
---@param pid integer @ 技能拥有角色id
---@param skill Skill @ 要更新的技能
local function updateLimitSkill(pid, skill)
  if not skill.visible then return end
  local player = ClientInstance:getPlayerById(pid)
  local times = -2
  local skill_name = skill:getSkeleton().name
  if skill:hasTag(Skill.Switch) or skill:hasTag(skill.Rhyme) then
    times = player:getSwitchSkillState(skill_name) == fk.SwitchYang and 0 or 1
  elseif skill:hasTag(Skill.Limited) or skill:hasTag(Skill.Wake) then
    times = player:usedSkillTimes(skill_name, Player.HistoryGame)
  elseif skill:hasTag(Skill.Quest) then
    times = -1
    local state = player:getQuestSkillState(skill_name)
    if state then
      times = state == "failed" and 2 or 1
    end
  end
  if times > -2 then
    if not player:hasSkill(skill_name, true) then
      times = -1
    end
    ClientInstance:notifyUI("UpdateLimitSkill", { pid, skill_name, times })
  end
end

function Client:loseSkill(data)
  -- jsonData: [ int player_id, string skill_name ]
  local id, skill_name, fake = data[1], data[2], data[3]
  local target = self:getPlayerById(id)
  local skill = Fk.skills[skill_name]

  if fake then
    target:loseFakeSkill(skill)
  else
    target:loseSkill(skill)
  end

  if not fake then
    if skill.visible then
      self:notifyUI("LoseSkill", data)
    end
  elseif skill.visible then
    -- 按理说能弄得更好的但还是复制粘贴舒服
    local sks = { table.unpack(skill.related_skills) }
    table.insert(sks, skill)
    table.removeOne(target.player_skills, skill)
    local chk = false

    if table.find(sks, function(s) return s:isInstanceOf(TriggerSkill) end) then
      chk = true
      self:notifyUI("LoseSkill", data)
    end

    local active = table.filter(sks, function(s)
      return s:isInstanceOf(ActiveSkill) or s:isInstanceOf(ViewAsSkill)
    end)

    if #active > 0 then
      chk = true
      self:notifyUI("LoseSkill", {
        id, skill_name,
      })
    end

    if not chk then
      self:notifyUI("LoseSkill", {
        id, skill_name,
      })
    end
  end

  updateLimitSkill(id, skill)
end

function Client:addSkill(data)
  -- jsonData: [ int player_id, string skill_name ]
  local id, skill_name, fake = data[1], data[2], data[3]
  local target = self:getPlayerById(id)
  local skill = Fk.skills[skill_name]

  if fake then
    target:addFakeSkill(skill)
  else
    target:addSkill(skill)
  end

  if not fake then
    if skill.visible then
      self:notifyUI("AddSkill", data)
    end
  elseif skill.visible then
    -- 添加假技能：服务器只会传一个主技能来。
    -- 若有主动技则添加按钮，若有触发技则添加预亮按钮。
    -- 无视状态技。
    -- TODO：根据skel判断，是refresh和delay就不添加按钮
    local sks = { table.unpack(skill.related_skills) }
    table.insert(sks, skill)
    table.insert(target.player_skills, skill)
    local chk = false

    if table.find(sks, function(s) return s:isInstanceOf(TriggerSkill) and not s.is_delay_effect end) then
      chk = true
      self:notifyUI("AddSkill", data)
    end

    local active = table.filter(sks, function(s)
      return s:isInstanceOf(ActiveSkill) or s:isInstanceOf(ViewAsSkill)
    end)

    if #active > 0 then
      chk = true
      self:notifyUI("AddSkill", {
        id, skill_name,
      })
    end

    -- 面板上总得有点啥东西表明自己有技能吧 = =
    if not chk then
      self:notifyUI("AddSkill", {
        id, skill_name,
      })
    end
  end


  updateLimitSkill(id, skill)
end

function Client:addStatusSkill(data)
  -- jsonData: [ string skill_name ]
  local skill_name = data[1]
  local skill = Fk.skills[skill_name]
  self.status_skills[skill.class] = self.status_skills[skill.class] or {}
  table.insertIfNeed(self.status_skills[skill.class], skill)
end

function Client:askForSkillInvoke(data)
  -- jsonData: [ string name, string prompt ]

  self:setupRequestHandler(Self, "AskForSkillInvoke")
  self.current_request_handler.prompt = data[2]
  self:notifyUI("AskForSkillInvoke", data)
end

function Client:askForUseActiveSkill(data)
  -- jsonData: [ string skill_name, string prompt, bool cancelable. json extra_data ]
  local skill = Fk.skills[data[1]]
  local extra_data = data[4]
  skill._extra_data = extra_data
  Fk.currentResponseReason = extra_data.skillName

  self:setupRequestHandler(Self, "AskForUseActiveSkill", data)
  self:notifyUI("AskForUseActiveSkill", data)
end

function Client:askForUseCard(data)
  -- jsonData: card, pattern, prompt, cancelable, {}
  Fk.currentResponsePattern = data[2]
  self:setupRequestHandler(Self, "AskForUseCard", data)
  self:notifyUI("AskForUseCard", data)
end

function Client:askForResponseCard(data)
  -- jsonData: card, pattern, prompt, cancelable, {}
  Fk.currentResponsePattern = data[2]
  self:setupRequestHandler(Self, "AskForResponseCard", data)
  self:notifyUI("AskForResponseCard", data)
end

function Client:handleSetCurrent(data)
  -- jsonData: [ int id ]
  local playerId = data[1]
  self:setCurrent(self:getPlayerById(playerId))
end

function Client:setCardMark(data)
  -- jsonData: [ int id, string mark, int value ]
  local card, mark, value = data[1], data[2], data[3]
  Fk:getCardById(card):setMark(mark, value)

  self:notifyUI("UpdateCard", card)
end

function Client:logEvent(data)
  if data.type == "Death" then
    table.removeOne(
      self.alive_players,
      self:getPlayerById(data.to)
    )
  end
  self:notifyUI("LogEvent", data)
end

function Client:addCardUseHistory(data)
  local playerid, card_name, num = table.unpack(data)
  local player = self:getPlayerById(playerid)
  player:addCardUseHistory(card_name, num)
end

function Client:setCardUseHistory(data)
  local playerid, card_name, num, scope = table.unpack(data)
  local player = self:getPlayerById(playerid)
  player:setCardUseHistory(card_name, num, scope)
end

function Client:addSkillUseHistory(data)
  local playerid, skill_name, time = data[1], data[2], data[3]
  local player = self:getPlayerById(playerid)
  player:addSkillUseHistory(skill_name, time)

  local skill = Fk.skills[skill_name]
  if not skill then return end
  updateLimitSkill(playerid, Fk.skills[skill_name])
end

function Client:addSkillBranchUseHistory(data)
  local playerid, skill_name, branch, time = data[1], data[2], data[3], data[4]
  local player = self:getPlayerById(playerid)
  player:addSkillBranchUseHistory(skill_name, branch, time)

  -- 真的有分支会改变状态吗……？
  -- local skill = Fk.skills[skill_name]
  -- if not skill then return end
  -- updateLimitSkill(playerid, Fk.skills[skill_name])
end

function Client:setSkillUseHistory(data)
  local id, skill_name, time, scope = data[1], data[2], data[3], data[4]
  local player = self:getPlayerById(id)
  player:setSkillUseHistory(skill_name, time, scope)

  local skill = Fk.skills[skill_name]
  if not skill then return end
  updateLimitSkill(id, Fk.skills[skill_name])
end

function Client:setSkillBranchUseHistory(data)
  local id, skill_name, branch, time, scope =
                                    data[1], data[2], data[3], data[4], data[5]
  local player = self:getPlayerById(id)
  if not player then return end
  player:setSkillBranchUseHistory(skill_name, branch, time, scope)

  -- 真的有分支会改变状态吗……？
  -- local skill = Fk.skills[skill_name]
  -- if not skill then return end
  -- updateLimitSkill(id, Fk.skills[skill_name])
end

function Client:addVirtualEquip(data)
  local cname = data.name
  local player = self:getPlayerById(data.player)
  local subcards = data.subcards
  local c = Fk:cloneCard(cname)
  c:addSubcards(subcards)
  player:addVirtualEquip(c)
end

function Client:removeVirtualEquip(data)
  local player = self:getPlayerById(data.player)
  player:removeVirtualEquip(data.id)
end

function Client:changeSelf(data)
  local pid = tonumber(data) --[[@as integer]]
  self.client:changeSelf(pid) -- for qml
  Self = self:getPlayerById(pid)
  self:notifyUI("ChangeSelf", pid)
end

function Client:updateQuestSkillUI(data)
  local playerId, skillName = data[1], data[2]
  updateLimitSkill(playerId, Fk.skills[skillName])
end

function Client:UpdateMarkArea(data)
  local player = ClientInstance:getPlayerById(data.id)
  for key, value in pairs(data.change) do
    player.markArea[key] = value
  end
  self:notifyUI("UpdateMarkArea", data)
end

function Client:handlePrintCard(data)
  local n, s, num = table.unpack(data)
  AbstractRoom.printCard(self, n, s, num)
end

function Client:addBuddy(data)
  local fromid, id = table.unpack(data)
  local from = self:getPlayerById(fromid)
  local to = self:getPlayerById(id)
  from:addBuddy(to)
end

function Client:rmBuddy(data)
  local fromid, id = table.unpack(data)
  local from = self:getPlayerById(fromid)
  local to = self:getPlayerById(id)
  from:removeBuddy(to)
end

function Client:handleShuffleDrawPile(data)
  self:shuffleDrawPile(data)
  self:appendLog {
    type = "$ShuffleDrawPile",
    arg = #self.draw_pile,
  }
end

function Client:syncDrawPile(data)
  self.draw_pile = data
end

function Client:handleChangeCardArea(data)
  local cards, area, areaCards = table.unpack(data)
  self:changeCardArea(cards, area, areaCards)
end

function Client:setPlayerPile(data)
  local pid, pile, ids = table.unpack(data)
  local player = ClientInstance:getPlayerById(pid)
  player.special_cards[pile] = ids
end

function Client:handleFilterCard(data)
  local cid, player, judgeEvent = data[1], data[2], data[3]
  self:filterCard(cid, player, judgeEvent)
end

function Client:showVirtualCard(data)
  local card, playerid, msg, event_id = table.unpack(data)
  if msg then msg = self:parseMsg(msg, true) end
  if type(card) == "table" and card.class and card:isInstanceOf(Card) then
    card = {card}
  end
  self:notifyUI("ShowVirtualCard", { card, playerid, msg, event_id })
end

function Client:changeSkin(data)
  self:notifyUI("ChangeSkin", data)
end

function Client:sendDataToUI(data)
  ClientBase.sendDataToUI(self)

  self:notifyUI("UpdateRoundNum", data.round_count)
end

return Client
