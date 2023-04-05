---@class Client
---@field public client fk.Client
---@field public players ClientPlayer[]
---@field public alive_players ClientPlayer[]
---@field public observers ClientPlayer[]
---@field public current ClientPlayer
---@field public discard_pile integer[]
---@field public status_skills Skill[]
Client = class('Client')

-- load client classes
ClientPlayer = require "client.clientplayer"

fk.client_callback = {}

function Client:initialize()
  self.client = fk.ClientInstance
  self.notifyUI = function(self, command, jsonData)
    fk.Backend:emitNotifyUI(command, jsonData)
  end
  self.client.callback = function(_self, command, jsonData)
    local cb = fk.client_callback[command]
    if (type(cb) == "function") then
      cb(jsonData)
    else
      self:notifyUI(command, jsonData);
    end
  end

  self.players = {}     -- ClientPlayer[]
  self.alive_players = {}
  self.observers = {}
  self.discard_pile = {}
  self.status_skills = {}
  for class, skills in pairs(Fk.global_status_skill) do
    self.status_skills[class] = {table.unpack(skills)}
  end
end

---@param id integer
---@return ClientPlayer
function Client:getPlayerById(id)
  for _, p in ipairs(self.players) do
    if p.id == id then return p end
  end
  return nil
end

---@param cardId integer | card
---@return CardArea
function Client:getCardArea(cardId)
  if type(cardId) ~= "number" then
    assert(cardId and cardId:isInstanceOf(Card))
    cardId = cardId:getEffectiveId()
  end
  if table.contains(Self.player_cards[Player.Hand], cardId) then
    return Card.PlayerHand
  end
  if table.contains(Self.player_cards[Player.Equip], cardId) then
    return Card.PlayerEquip
  end
  for _, t in pairs(Self.special_cards) do
    if table.contains(t, cardId) then
      return Card.PlayerSpecial
    end
  end
  error("Client:getCardArea can only judge cards in your hand or equip area")
end

function Client:moveCards(moves)
  for _, move in ipairs(moves) do
    if move.from and move.fromArea then
      local from = self:getPlayerById(move.from)
      if from.id ~= Self.id and move.fromArea == Card.PlayerHand then
        for i = 1, #move.ids do
          table.remove(from.player_cards[Player.Hand])
        end
      else
        from:removeCards(move.fromArea, move.ids, move.fromSpecialName)
      end
    elseif move.fromArea == Card.DiscardPile then
      table.removeOne(self.discard_pile, move.ids[1])
    end

    if move.to and move.toArea then
      local ids = move.ids
      if (move.to ~= Self.id and move.toArea == Card.PlayerHand) or table.contains(ids, -1) then
        ids = table.map(ids, function() return -1 end)
      end
      self:getPlayerById(move.to):addCards(move.toArea, ids, move.specialName)
    elseif move.toArea == Card.DiscardPile then
      table.insert(self.discard_pile, move.ids[1])
    end

    if (move.ids[1] ~= -1) then
      Fk:filterCard(move.ids[1], ClientInstance:getPlayerById(move.to))
    end
  end
end

---@param msg LogMessage
function Client:appendLog(msg)
  local data = msg
  local function getPlayerStr(pid, color)
    if not pid then
      return ""
    end
    local ret = self:getPlayerById(pid)
    ret = ret.general
    ret = Fk:translate(ret)
    ret = string.format('<font color="' .. color .. '"><b>%s</b></font>', ret)
    return ret
  end

  local from = getPlayerStr(data.from, "#0C8F0C")

  local to = data.to or {}
  local to_str = {}
  for _, id in ipairs(to) do
    table.insert(to_str, getPlayerStr(id, "#CC3131"))
  end
  to = table.concat(to_str, ", ")

  local card = data.card or {}
  local allUnknown = true
  local unknownCount = 0
  for _, id in ipairs(card) do
    if id ~= -1 then
      allUnknown = false
    else
      unknownCount = unknownCount + 1
    end
  end

  if allUnknown then
    card = ""
  else
    local card_str = {}
    for _, id in ipairs(card) do
      table.insert(card_str, Fk:getCardById(id, true):toLogString())
    end
    if unknownCount > 0 then
      table.insert(card_str, Fk:translate("unknown_card")
        .. unknownCount == 1 and "x" .. unknownCount or "")
    end
    card = table.concat(card_str, ", ")
  end

  local function parseArg(arg)
    arg = arg or ""
    arg = Fk:translate(arg)
    arg = string.format('<font color="#0598BC"><b>%s</b></font>', arg)
    return arg
  end

  local arg = parseArg(data.arg)
  local arg2 = parseArg(data.arg2)
  local arg3 = parseArg(data.arg3)

  local log = Fk:translate(data.type)
  log = string.gsub(log, "%%from", from)
  log = string.gsub(log, "%%to", to)
  log = string.gsub(log, "%%card", card)
  log = string.gsub(log, "%%arg2", arg2)
  log = string.gsub(log, "%%arg3", arg3)
  log = string.gsub(log, "%%arg", arg)
  self:notifyUI("GameLog", log)
end

fk.client_callback["Setup"] = function(jsonData)
  -- jsonData: [ int id, string screenName, string avatar ]
  local data = json.decode(jsonData)
  local id, name, avatar = data[1], data[2], data[3]
  local self = fk.Self
  self:setId(id)
  self:setScreenName(name)
  self:setAvatar(avatar)
  Self = ClientPlayer:new(fk.Self)
end

fk.client_callback["EnterRoom"] = function(jsonData)
  Self = ClientPlayer:new(fk.Self)
  ClientInstance = Client:new() -- clear old client data
  ClientInstance.players = {Self}
  ClientInstance.alive_players = {Self}
  ClientInstance.discard_pile = {}

  local data = json.decode(jsonData)[3]
  Fk.disabled_packs = data.disabledPack
  ClientInstance:notifyUI("EnterRoom", jsonData)
end

fk.client_callback["AddPlayer"] = function(jsonData)
  -- jsonData: [ int id, string screenName, string avatar ]
  -- when other player enter the room, we create clientplayer(C and lua) for them
  local data = json.decode(jsonData)
  local id, name, avatar = data[1], data[2], data[3]
  local player = fk.ClientInstance:addPlayer(id, name, avatar)
  local p = ClientPlayer:new(player)
  table.insert(ClientInstance.players, p)
  table.insert(ClientInstance.alive_players, p)
  ClientInstance:notifyUI("AddPlayer", jsonData)
end

fk.client_callback["RemovePlayer"] = function(jsonData)
  -- jsonData: [ int id ]
  local data = json.decode(jsonData)
  local id = data[1]
  for _, p in ipairs(ClientInstance.players) do
    if p.player:getId() == id then
      table.removeOne(ClientInstance.players, p)
      table.removeOne(ClientInstance.alive_players, p)
      break
    end
  end
  if id ~= Self.id then
    fk.ClientInstance:removePlayer(id)
    ClientInstance:notifyUI("RemovePlayer", jsonData)
  end
end

fk.client_callback["AddObserver"] = function(jsonData)
  -- jsonData: [ int id, string screenName, string avatar ]
  -- when observer enter the room, we create lua clientplayer for them
  local data = json.decode(jsonData)
  local id, name, avatar = data[1], data[2], data[3]
  local player = {
    getId = function() return id end,
    getScreenName = function() return name end,
    getAvatar = function() return avatar end,
  }
  local p = ClientPlayer:new(player)
  table.insert(ClientInstance.observers, p)
end

fk.client_callback["RemoveObserver"] = function(jsonData)
  local data = json.decode(jsonData)
  local id = data[1]
  for _, p in ipairs(ClientInstance.observers) do
    if p.player:getId() == id then
      table.removeOne(ClientInstance.observers, p)
      break
    end
  end
end

fk.client_callback["ArrangeSeats"] = function(jsonData)
  local data = json.decode(jsonData)
  local n = #ClientInstance.players
  local players = {}

  for i = 1, n do
    local p = ClientInstance:getPlayerById(data[i])
    p.seat = i
    table.insert(players, p)
  end

  for i = 1, #players - 1 do
    players[i].next = players[i + 1]
  end
  players[#players].next = players[1]

  ClientInstance.players = players

  ClientInstance:notifyUI("ArrangeSeats", jsonData)
end

fk.client_callback["PropertyUpdate"] = function(jsonData)
  -- jsonData: [ int id, string property_name, value ]
  local data = json.decode(jsonData)
  local id, name, value = data[1], data[2], data[3]
  ClientInstance:getPlayerById(id)[name] = value
  ClientInstance:notifyUI("PropertyUpdate", jsonData)
end

fk.client_callback["AskForCardChosen"] = function(jsonData)
  -- jsonData: [ int target_id, string flag, int reason ]
  local data = json.decode(jsonData)
  local id, flag, reason = data[1], data[2], data[3]
  local target = ClientInstance:getPlayerById(id)
  local hand = target.player_cards[Player.Hand]
  local equip = target.player_cards[Player.Equip]
  local judge = target.player_cards[Player.Judge]
  if not string.find(flag, "h") then
    hand = {}
  elseif target.id ~= Self.id then
    -- FIXME: can not see other's handcard
    hand = table.map(hand, function() return -1 end)
  end
  if not string.find(flag, "e") then
    equip = {}
  end
  if not string.find(flag, "j") then
    judge = {}
  end
  local ui_data = {hand, equip, judge, reason}
  ClientInstance:notifyUI("AskForCardChosen", json.encode(ui_data))
end

fk.client_callback["AskForCardsChosen"] = function(jsonData)
  -- jsonData: [ int target_id, int min, int max, string flag, int reason ]
  local data = json.decode(jsonData)
  local id, min, max, flag, reason = data[1], data[2], data[3], data[4], data[5]
  local target = ClientInstance:getPlayerById(id)
  local hand = target.player_cards[Player.Hand]
  local equip = target.player_cards[Player.Equip]
  local judge = target.player_cards[Player.Judge]
  if not string.find(flag, "h") then
    hand = {}
  end
  if not string.find(flag, "e") then
    equip = {}
  end
  if not string.find(flag, "j") then
    judge = {}
  end
  local ui_data = {hand, equip, judge, min, max, reason}
  ClientInstance:notifyUI("AskForCardsChosen", json.encode(ui_data))
end

--- separated moves to many moves(one card per move)
---@param moves CardsMoveStruct[]
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
    local info = string.format("%q,%q,%q,%q,%s,%s",
      move.from, move.to, move.fromArea, move.toArea,
      move.specialName, move.fromSpecialName)
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
      }
    end
    table.insert(temp[info].ids, move.ids[1])
  end
  for _, v in pairs(temp) do
    table.insert(ret, v)
  end
  return ret
end

local function sendMoveCardLog(move)
  if #move.ids == 0 then return end
  local hidden = table.contains(move.ids, -1)
  local msgtype

  if move.from and move.toArea == Card.DrawPile then
    msgtype = hidden and "$PutCard" or "$PutKnownCard"
    ClientInstance:appendLog{
      type = msgtype,
      from = move.from,
      card = move.ids,
      arg = #move.ids,
    }
  elseif move.toArea == Card.PlayerSpecial then
    msgtype = hidden and "$RemoveCardFromGame" or "$AddToPile"
    ClientInstance:appendLog{
      type = msgtype,
      arg = move.specialName,
      arg2 = #move.ids,
      card = move.ids,
    }
  elseif move.fromArea == Card.PlayerSpecial and move.to then
    ClientInstance:appendLog{
      type = "$GetCardsFromPile",
      from = move.to,
      arg = move.fromSpecialName,
      arg2 = #move.ids,
      card = move.ids,
    }
  elseif move.fromArea == Card.DrawPile and move.toArea == Card.PlayerHand then
    ClientInstance:appendLog{
      type = "$DrawCards",
      from = move.to,
      card = move.ids,
      arg = #move.ids,
    }
  elseif (move.fromArea == Card.Processing or move.fromArea == Card.PlayerJudge)
    and move.toArea == Card.PlayerHand then
    ClientInstance:appendLog{
      type = "$GotCardBack",
      from = move.to,
      card = move.ids,
      arg = #move.ids,
    }
  elseif move.fromArea == Card.DiscardPile and move.toArea == Card.PlayerHand then
    ClientInstance:appendLog{
      type = "$RecycleCard",
      from = move.to,
      card = move.ids,
      arg = #move.ids,
    }
  elseif move.from and move.fromArea ~= Card.PlayerJudge and
    move.toArea ~= Card.PlayerJudge and move.to and move.from ~= move.to then
    ClientInstance:appendLog{
      type = "$MoveCards",
      from = move.from,
      to = { move.to },
      arg = #move.ids,
      card = move.ids,
    }
  elseif move.from and move.to and move.toArea == Card.PlayerJudge then
    if move.fromArea == Card.PlayerJudge and move.from ~= move.to then
      msgtype = "$LightningMove"
    elseif move.fromArea ~= Card.PlayerJudge then
      msgtype = "$PasteCard"
    end
    if msgtype then
      ClientInstance:appendLog{
        type = msgtype,
        from = move.from,
        to = { move.to },
        card = move.ids,
      }
    end
  end

  -- TODO ...
  if move.moveReason == fk.ReasonDiscard then
    ClientInstance:appendLog{
      type = "$DiscardCards",
      from = move.from,
      card = move.ids,
      arg = #move.ids,
    }
  end
end

fk.client_callback["MoveCards"] = function(jsonData)
  -- jsonData: CardsMoveStruct[]
  local raw_moves = json.decode(jsonData)
  local separated = separateMoves(raw_moves)
  ClientInstance:moveCards(separated)
  local merged = mergeMoves(separated)
  for _, move in ipairs(merged) do
    sendMoveCardLog(move)
  end
  ClientInstance:notifyUI("MoveCards", json.encode(merged))
end

fk.client_callback["ShowCard"] = function(jsonData)
  local data = json.decode(jsonData)
  local from = data.from
  local cards = data.cards
  ClientInstance:notifyUI("MoveCards", json.encode{
    {
      ids = cards,
      fromArea = Card.DrawPile,
      toArea = Card.Processing,
    }
  })
end

fk.client_callback["LoseSkill"] = function(jsonData)
  -- jsonData: [ int player_id, string skill_name ]
  local data = json.decode(jsonData)
  local id, skill_name = data[1], data[2]
  local target = ClientInstance:getPlayerById(id)
  local skill = Fk.skills[skill_name]
  target:loseSkill(skill)
  if skill.visible then
    ClientInstance:notifyUI("LoseSkill", jsonData)
  end
end

-- 说是限定技，其实也适用于觉醒技、转换技、使命技
---@param skill Skill
---@param times integer
local function updateLimitSkill(pid, skill, times)
  if not skill.visible then return end
  if skill.frequency == Skill.Limited or skill.frequency == Skill.Wake then
    ClientInstance:notifyUI("UpdateLimitSkill", json.encode{ pid, skill.name, times })
  end
end

fk.client_callback["AddSkill"] = function(jsonData)
  -- jsonData: [ int player_id, string skill_name ]
  local data = json.decode(jsonData)
  local id, skill_name = data[1], data[2]
  local target = ClientInstance:getPlayerById(id)
  local skill = Fk.skills[skill_name]
  target:addSkill(skill)
  if skill.visible then
    ClientInstance:notifyUI("AddSkill", jsonData)
  end

  updateLimitSkill(id, skill, target:usedSkillTimes(skill_name, Player.HistoryGame))
end

fk.client_callback["AskForUseActiveSkill"] = function(jsonData)
  -- jsonData: [ string skill_name, string prompt, bool cancelable. json extra_data ]
  local data = json.decode(jsonData)
  local skill = Fk.skills[data[1]]
  local extra_data = json.decode(data[4])
  for k, v in pairs(extra_data) do
    skill[k] = v
  end
  ClientInstance:notifyUI("AskForUseActiveSkill", jsonData)
end

fk.client_callback["SetPlayerMark"] = function(jsonData)
  -- jsonData: [ int id, string mark, int value ]
  local data = json.decode(jsonData)
  local player, mark, value = data[1], data[2], data[3]
  ClientInstance:getPlayerById(player):setMark(mark, value)

  if string.sub(mark, 1, 1) == "@" then
    ClientInstance:notifyUI("SetPlayerMark", jsonData)
  end
end

fk.client_callback["Chat"] = function(jsonData)
  -- jsonData: { int type, int sender, string msg }
  local data = json.decode(jsonData)
  if data.type == 1 then
    data.general = ""
    data.time = os.date("%H:%M:%S")
    ClientInstance:notifyUI("Chat", json.encode(data))
    return
  end

  local p = ClientInstance:getPlayerById(data.sender)
  -- TODO: observer chatting
  if not p then
    for _, pl in ipairs(ClientInstance.observers) do
      if pl.id == data.sender then
        p = pl; break
      end
    end
    if not p then return end
    data.general = ""
  else
    data.general = p.general
  end
  data.userName = p.player:getScreenName()
  data.time = os.date("%H:%M:%S")
  ClientInstance:notifyUI("Chat", json.encode(data))
end

fk.client_callback["GameLog"] = function(jsonData)
  local data = json.decode(jsonData)
  ClientInstance:appendLog(data)
end

fk.client_callback["LogEvent"] = function(jsonData)
  local data = json.decode(jsonData)
  if data.type == "Death" then
    table.removeOne(
      ClientInstance.alive_players,
      ClientInstance:getPlayerById(data.to)
    )
  end
  ClientInstance:notifyUI("LogEvent", jsonData)
end

fk.client_callback["AddCardUseHistory"] = function(jsonData)
  local data = json.decode(jsonData)
  Self:addCardUseHistory(data[1], data[2])
end

fk.client_callback["SetCardUseHistory"] = function(jsonData)
  local data = json.decode(jsonData)
  Self:setCardUseHistory(data[1], data[2], data[3])
end

fk.client_callback["AddSkillUseHistory"] = function(jsonData)
  local data = json.decode(jsonData)
  local playerid, skill_name, time = data[1], data[2], data[3]
  local player = ClientInstance:getPlayerById(playerid)
  player:addSkillUseHistory(skill_name, time)
  if not Fk.skills[skill_name] then return end
  updateLimitSkill(playerid, Fk.skills[skill_name], player:usedSkillTimes(skill_name, Player.HistoryGame))
end

fk.client_callback["SetSkillUseHistory"] = function(jsonData)
  local data = json.decode(jsonData)
  local id, skill_name, time, scope = data[1], data[2], data[3], data[4]
  local player = ClientInstance:getPlayerById(id)
  player:setSkillUseHistory(skill_name, time, scope)
  if not Fk.skills[skill_name] then return end
  updateLimitSkill(id, Fk.skills[skill_name], player:usedSkillTimes(skill_name, Player.HistoryGame))
end

fk.client_callback["AddVirtualEquip"] = function(jsonData)
  local data = json.decode(jsonData)
  local cname = data.name
  local player = ClientInstance:getPlayerById(data.player)
  local subcards = data.subcards
  local c = Fk:cloneCard(cname)
  c:addSubcards(subcards)
  player:addVirtualEquip(c)
end

fk.client_callback["RemoveVirtualEquip"] = function(jsonData)
  local data = json.decode(jsonData)
  local player = ClientInstance:getPlayerById(data.player)
  player:removeVirtualEquip(data.id)
end

fk.client_callback["Heartbeat"] = function()
  ClientInstance.client:notifyServer("Heartbeat", "")
end

-- Create ClientInstance (used by Lua)
ClientInstance = Client:new()
dofile "lua/client/client_util.lua"
