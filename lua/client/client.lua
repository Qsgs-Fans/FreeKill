-- SPDX-License-Identifier: GPL-3.0-or-later

---@class Client : AbstractRoom
---@field public client fk.Client
---@field public players ClientPlayer[] @ 所有参战玩家的数组
---@field public alive_players ClientPlayer[] @ 所有存活玩家的数组
---@field public observers ClientPlayer[] @ 观察者的数组
---@field public current ClientPlayer @ 当前回合玩家
---@field public discard_pile integer[] @ 弃牌堆
---@field public observing boolean
Client = AbstractRoom:subclass('Client')

-- load client classes
ClientPlayer = require "client.clientplayer"

fk.client_callback = {}

-- 总而言之就是会让roomScene.state变为responding或者playing的状态
local pattern_refresh_commands = {
  "PlayCard",
  "AskForUseActiveSkill",
  "AskForUseCard",
  "AskForResponseCard",
}

function Client:initialize()
  AbstractRoom.initialize(self)
  self.client = fk.ClientInstance
  self.notifyUI = function(self, command, jsonData)
    fk.Backend:emitNotifyUI(command, jsonData)
  end
  self.client.callback = function(_self, command, jsonData, isRequest)
    if self.recording then
      table.insert(self.record, {math.floor(os.getms() / 1000), isRequest, command, jsonData})
    end

    local cb = fk.client_callback[command]

    if table.contains(pattern_refresh_commands, command) then
      Fk.currentResponsePattern = nil
      Fk.currentResponseReason = nil
    end

    if (type(cb) == "function") then
      cb(jsonData)
    else
      self:notifyUI(command, jsonData);
    end
  end

  self.discard_pile = {}
  self._processing = {}

  self.disabled_packs = {}
  self.disabled_generals = {}

  self.recording = false
end

---@param id integer
---@return ClientPlayer?
function Client:getPlayerById(id)
  if id == Self.id then return Self end
  for _, p in ipairs(self.players) do
    if p.id == id then return p end
  end
  return nil
end

---@param cardId integer | Card
---@return CardArea
function Client:getCardArea(cardId)
  local cardIds = Card:getIdList(cardId)
  local resultPos = {}
  for _, cid in ipairs(cardIds) do
    if not table.contains(resultPos, Card.PlayerHand) and table.contains(Self.player_cards[Player.Hand], cid) then
      table.insert(resultPos, Card.PlayerHand)
    end
    if not table.contains(resultPos, Card.PlayerEquip) and table.contains(Self.player_cards[Player.Equip], cid) then
      table.insert(resultPos, Card.PlayerEquip)
    end
    for _, t in pairs(Self.special_cards) do
      if table.contains(t, cid) then
        table.insertIfNeed(resultPos, Card.PlayerSpecial)
      end
    end
  end
  if #resultPos == 1 then
    return resultPos[1]
  end
  return Card.Unknown
end

function Client:moveCards(moves)
  for _, move in ipairs(moves) do
    if move.from and move.fromArea then
      local from = self:getPlayerById(move.from)
      self:notifyUI("MaxCard", json.encode{
        pcardMax = from:getMaxCards(),
        id = move.from,
      })
      if move.fromArea == Card.PlayerHand and not Self:isBuddy(self:getPlayerById(move.from)) then
        for _ = 1, #move.ids do
          table.remove(from.player_cards[Player.Hand])
        end
      else
        if table.contains({ Player.Hand, Player.Equip, Player.Judge, Player.Special }, move.fromArea) then
          from:removeCards(move.fromArea, move.ids, move.fromSpecialName)
        end
      end
    elseif move.fromArea == Card.DiscardPile then
      table.removeOne(self.discard_pile, move.ids[1])
    end

    if move.to and move.toArea then
      local ids = move.ids
      self:notifyUI("MaxCard", json.encode{
        pcardMax = self:getPlayerById(move.to):getMaxCards(),
        id = move.to,
      })
      if (not Self:isBuddy(self:getPlayerById(move.to)) and move.toArea == Card.PlayerHand) or table.contains(ids, -1) then
        ids = table.map(ids, function() return -1 end)
      end
      self:getPlayerById(move.to):addCards(move.toArea, ids, move.specialName)
    elseif move.toArea == Card.DiscardPile then
      table.insert(self.discard_pile, move.ids[1])
    end

    -- FIXME: 需要系统化的重构
    if move.fromArea == Card.Processing then
      for _, v in ipairs(move.ids) do
        self._processing[v] = nil
      end
    end
    if move.toArea == Card.Processing then
      for _, v in ipairs(move.ids) do
        self._processing[v] = true
      end
    end

    if (move.ids[1] ~= -1) then
      Fk:filterCard(move.ids[1], ClientInstance:getPlayerById(move.to))
    end
  end
end

---@param msg LogMessage
local function parseMsg(msg, nocolor)
  local self = ClientInstance
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
      return string.format(str, color, ret)
    end

    local ret = p.general
    ret = Fk:translate(ret)
    if p.deputyGeneral and p.deputyGeneral ~= "" then
      ret = ret .. "/" .. Fk:translate(p.deputyGeneral)
    end
    ret = string.format(str, color, ret)
    return ret
  end

  local from = getPlayerStr(data.from, "#0C8F0C")

  local to = data.to or Util.DummyTable
  local to_str = {}
  for _, id in ipairs(to) do
    table.insert(to_str, getPlayerStr(id, "#CC3131"))
  end
  to = table.concat(to_str, ", ")

  local card = data.card or Util.DummyTable
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
    arg = string.format('<font color="%s"><b>%s</b></font>', nocolor and "white" or "#0598BC", arg)
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
  return log
end

---@param msg LogMessage
function Client:appendLog(msg)
  local text = parseMsg(msg)
  self:notifyUI("GameLog", text)
  if msg.toast then
    self:notifyUI("ShowToast", text)
  end
end

---@param msg LogMessage
function Client:setCardNote(ids, msg)
  for _, id in ipairs(ids) do
    if id ~= -1 then
      self:notifyUI("SetCardFootnote", json.encode{ id, parseMsg(msg, true) })
    end
  end
end

fk.client_callback["SetCardFootnote"] = function(jsonData)
  local data = json.decode(jsonData)
  ClientInstance:setCardNote(data[1], data[2]);
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

  local _data = json.decode(jsonData)
  local data = _data[3]
  ClientInstance.enter_room_data = jsonData;
  ClientInstance.room_settings = data
  table.insertTableIfNeed(
    data.disabledPack,
    Fk.game_mode_disabled[data.gameMode]
  )
  ClientInstance.disabled_packs = data.disabledPack
  ClientInstance.disabled_generals = data.disabledGenerals
  ClientInstance:notifyUI("EnterRoom", jsonData)
end

fk.client_callback["AddPlayer"] = function(jsonData)
  -- jsonData: [ int id, string screenName, string avatar ]
  -- when other player enter the room, we create clientplayer(C and lua) for them
  local data = json.decode(jsonData)
  local id, name, avatar, time = data[1], data[2], data[3], data[5]
  local player = fk.ClientInstance:addPlayer(id, name, avatar)
  player:addTotalGameTime(time or 0) -- 以防再次智迟
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
  local p = ClientInstance:getPlayerById(id)
  p[name] = value

  if name == "dead" then
    if value == true then
      table.removeOne(ClientInstance.alive_players, p)
    else
      table.insertIfNeed(ClientInstance.alive_players, p)
    end
  end

  ClientInstance:notifyUI("PropertyUpdate", jsonData)
  ClientInstance:notifyUI("MaxCard", json.encode{
    pcardMax = ClientInstance:getPlayerById(id):getMaxCards(),
    id = id,
  })
end

fk.client_callback["AskForCardChosen"] = function(jsonData)
  -- jsonData: [ int target_id, string flag, int reason ]
  local data = json.decode(jsonData)
  local id, flag, reason, prompt = data[1], data[2], data[3], data[4]
  local target = ClientInstance:getPlayerById(id)
  local hand = target.player_cards[Player.Hand]
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
    ui_data = {
      _id = id,
      _reason = reason,
      card_data = {},
      _prompt = prompt,
    }
    if #hand ~= 0 then table.insert(ui_data.card_data, { "$Hand", hand }) end
    if #equip ~= 0 then table.insert(ui_data.card_data, { "$Equip", equip }) end
    if #judge ~= 0 then table.insert(ui_data.card_data, { "$Judge", judge }) end
  else
    ui_data._id = id
    ui_data._reason = reason
    ui_data._prompt = prompt
  end
  ClientInstance:notifyUI("AskForCardChosen", json.encode(ui_data))
end

fk.client_callback["AskForCardsChosen"] = function(jsonData)
  -- jsonData: [ int target_id, int min, int max, string flag, int reason ]
  local data = json.decode(jsonData)
  local id, min, max, flag, reason, prompt = data[1], data[2], data[3], data[4], data[5], data[6]
  local target = ClientInstance:getPlayerById(id)
  local hand = target.player_cards[Player.Hand]
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
    ui_data = {
      _id = id,
      _min = min,
      _max = max,
      _reason = reason,
      card_data = {},
      _prompt = prompt,
    }
    if #hand ~= 0 then table.insert(ui_data.card_data, { "$Hand", hand }) end
    if #equip ~= 0 then table.insert(ui_data.card_data, { "$Equip", equip }) end
    if #judge ~= 0 then table.insert(ui_data.card_data, { "$Judge", judge }) end
  else
    ui_data._id = id
    ui_data._min = min
    ui_data._max = max
    ui_data._reason = reason
    ui_data._prompt = prompt
  end
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
        proposer = move.proposer,
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
    table.insert(temp[info].ids, move.ids[1])
  end
  for _, v in pairs(temp) do
    table.insert(ret, v)
  end
  return ret
end

local function sendMoveCardLog(move)
  local client = ClientInstance ---@class Client
  if #move.ids == 0 then return end
  local hidden = table.contains(move.ids, -1)
  local msgtype

  if move.toArea == Card.PlayerHand then
    if move.fromArea == Card.PlayerSpecial then
      client:appendLog{
        type = "$GetCardsFromPile",
        from = move.to,
        arg = move.fromSpecialName,
        arg2 = #move.ids,
        card = move.ids,
      }
    elseif move.fromArea == Card.DrawPile then
      client:appendLog{
        type = "$DrawCards",
        from = move.to,
        card = move.ids,
        arg = #move.ids,
      }
    elseif move.fromArea == Card.Processing then
      client:appendLog{
        type = "$GotCardBack",
        from = move.to,
        card = move.ids,
        arg = #move.ids,
      }
    elseif move.fromArea == Card.DiscardPile then
      client:appendLog{
        type = "$RecycleCard",
        from = move.to,
        card = move.ids,
        arg = #move.ids,
      }
    elseif move.from then
      client:appendLog{
        type = "$MoveCards",
        from = move.from,
        to = { move.to },
        arg = #move.ids,
        card = move.ids,
      }
    else
      client:appendLog{
        type = "$PreyCardsFromPile",
        from = move.to,
        card = move.ids,
        arg = #move.ids,
      }
    end
  elseif move.toArea == Card.PlayerEquip then
    client:appendLog{
      type = "$InstallEquip",
      from = move.to,
      card = move.ids,
    }
  elseif move.toArea == Card.PlayerJudge then
    if move.from ~= move.to and move.fromArea == Card.PlayerJudge then
      client:appendLog{
        type = "$LightningMove",
        from = move.from,
        to = { move.to },
        card = move.ids,
      }
    elseif move.from then
      client:appendLog{
        type = "$PasteCard",
        from = move.from,
        to = { move.to },
        card = move.ids,
      }
    end
  elseif move.toArea == Card.PlayerSpecial then
    client:appendLog{
      type = "$AddToPile",
      arg = move.specialName,
      arg2 = #move.ids,
      from = move.to,
      card = move.ids,
    }
  elseif move.fromArea == Card.PlayerEquip then
    client:appendLog{
      type = "$UninstallEquip",
      from = move.from,
      card = move.ids,
    }
  -- elseif move.toArea == Card.Processing then
    -- nop
  elseif move.from and move.toArea == Card.DrawPile then
    msgtype = hidden and "$PutCard" or "$PutKnownCard"
    client:appendLog{
      type = msgtype,
      from = move.from,
      card = move.ids,
      arg = #move.ids,
    }
    client:setCardNote(move.ids, {
      type = "$$PutCard",
      from = move.from,
    })
  elseif move.toArea == Card.DiscardPile then
    if move.moveReason == fk.ReasonDiscard then
      if move.proposer and move.proposer ~= move.from then
        client:appendLog{
          type = "$DiscardOther",
          from = move.from,
          to = {move.proposer},
          card = move.ids,
          arg = #move.ids,
        }
      else
        client:appendLog{
          type = "$DiscardCards",
          from = move.from,
          card = move.ids,
          arg = #move.ids,
        }
      end
    elseif move.moveReason == fk.ReasonPutIntoDiscardPile then
      client:appendLog{
        type = "$PutToDiscard",
        card = move.ids,
        arg = #move.ids,
      }
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

fk.client_callback["MoveCards"] = function(jsonData)
  -- jsonData: CardsMoveStruct[]
  local raw_moves = json.decode(jsonData)
  local separated = separateMoves(raw_moves)
  ClientInstance:moveCards(separated)
  local merged = mergeMoves(separated)
  ClientInstance:notifyUI("MoveCards", json.encode(merged))
  for _, move in ipairs(merged) do
    sendMoveCardLog(move)
  end
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

-- 说是限定技，其实也适用于觉醒技、转换技、使命技
---@param skill Skill
---@param times integer
local function updateLimitSkill(pid, skill, times)
  if not skill.visible then return end
  if skill:isSwitchSkill() then
    local _times = ClientInstance:getPlayerById(pid):getSwitchSkillState(skill.switchSkillName) == fk.SwitchYang and 0 or 1
    if times == -1 then _times = -1 end
    ClientInstance:notifyUI("UpdateLimitSkill", json.encode{ pid, skill.switchSkillName, _times })
  elseif skill.frequency == Skill.Limited or skill.frequency == Skill.Wake or skill.frequency == Skill.Quest then
    ClientInstance:notifyUI("UpdateLimitSkill", json.encode{ pid, skill.name, times })
  end
end

fk.client_callback["LoseSkill"] = function(jsonData)
  -- jsonData: [ int player_id, string skill_name ]
  local data = json.decode(jsonData)
  local id, skill_name, fake = data[1], data[2], data[3]
  local target = ClientInstance:getPlayerById(id)
  local skill = Fk.skills[skill_name]

  if not fake then
    target:loseSkill(skill)
    if skill.visible then
      ClientInstance:notifyUI("LoseSkill", jsonData)
    end
  elseif skill.visible then
    -- 按理说能弄得更好的但还是复制粘贴舒服
    local sks = { table.unpack(skill.related_skills) }
    --[[ 需要大伙都适配好main_skill或者讨论出更好方案才行。不敢轻举妄动
    local sks = table.filter(skill.related_skills, function(s)
      return s.main_skill == skill
    end)
    --]]
    table.insert(sks, skill)
    table.removeOne(target.player_skills, skill)
    local chk = false

    if table.find(sks, function(s) return s:isInstanceOf(TriggerSkill) end) then
      chk = true
      ClientInstance:notifyUI("LoseSkill", jsonData)
    end

    local active = table.filter(sks, function(s)
      return s:isInstanceOf(ActiveSkill) or s:isInstanceOf(ViewAsSkill)
    end)

    if #active > 0 then
      chk = true
      ClientInstance:notifyUI("LoseSkill", json.encode {
        id, skill_name,
      })
    end

    if not chk then
      ClientInstance:notifyUI("LoseSkill", json.encode {
        id, skill_name,
      })
    end
  end

  updateLimitSkill(id, skill, -1)
end

fk.client_callback["AddSkill"] = function(jsonData)
  -- jsonData: [ int player_id, string skill_name ]
  local data = json.decode(jsonData)
  local id, skill_name, fake = data[1], data[2], data[3]
  local target = ClientInstance:getPlayerById(id)
  local skill = Fk.skills[skill_name]

  if not fake then
    target:addSkill(skill)
    if skill.visible then
      ClientInstance:notifyUI("AddSkill", jsonData)
    end
  elseif skill.visible then
    -- 添加假技能：服务器只会传一个主技能来。
    -- 若有主动技则添加按钮，若有触发技则添加预亮按钮。
    -- 无视状态技。
    local sks = { table.unpack(skill.related_skills) }
    table.insert(sks, skill)
    table.insert(target.player_skills, skill)
    local chk = false

    if table.find(sks, function(s) return s:isInstanceOf(TriggerSkill) end) then
      chk = true
      ClientInstance:notifyUI("AddSkill", jsonData)
    end

    local active = table.filter(sks, function(s)
      return s:isInstanceOf(ActiveSkill) or s:isInstanceOf(ViewAsSkill)
    end)

    if #active > 0 then
      chk = true
      ClientInstance:notifyUI("AddSkill", json.encode {
        id, skill_name,
      })
    end

    -- 面板上总得有点啥东西表明自己有技能吧 = =
    if not chk then
      ClientInstance:notifyUI("AddSkill", json.encode {
        id, skill_name,
      })
    end
  end

  if skill.frequency == Skill.Quest then
    return
  end

  updateLimitSkill(id, skill, target:usedSkillTimes(skill_name, Player.HistoryGame))
end

fk.client_callback["AskForUseActiveSkill"] = function(jsonData)
  -- jsonData: [ string skill_name, string prompt, bool cancelable. json extra_data ]
  local data = json.decode(jsonData)
  local skill = Fk.skills[data[1]]
  local extra_data = data[4]
  skill._extra_data = extra_data

  Fk.currentResponseReason = extra_data.skillName
  ClientInstance:notifyUI("AskForUseActiveSkill", jsonData)
end

fk.client_callback["AskForUseCard"] = function(jsonData)
  Fk.currentResponsePattern = json.decode(jsonData)[2]
  ClientInstance:notifyUI("AskForUseCard", jsonData)
end

fk.client_callback["AskForResponseCard"] = function(jsonData)
  Fk.currentResponsePattern = json.decode(jsonData)[2]
  ClientInstance:notifyUI("AskForResponseCard", jsonData)
end

fk.client_callback["SetPlayerMark"] = function(jsonData)
  -- jsonData: [ int id, string mark, int value ]
  local data = json.decode(jsonData)
  local player, mark, value = data[1], data[2], data[3]
  local p = ClientInstance:getPlayerById(player)
  p:setMark(mark, value)

  if string.sub(mark, 1, 1) == "@" then
    if mark:startsWith("@[") and mark:find(']') then
      local close = mark:find(']')
      local mtype = mark:sub(3, close - 1)
      local spec = Fk.qml_marks[mtype]
      if spec then
        local text = spec.how_to_show(mark, value, p)
        if text == "#hidden" then return end
      end
    end
    ClientInstance:notifyUI("SetPlayerMark", jsonData)
  end
end

fk.client_callback["SetBanner"] = function(jsonData)
  -- jsonData: [ int id, string mark, int value ]
  local data = json.decode(jsonData)
  local mark, value = data[1], data[2]
  ClientInstance:setBanner(mark, value)

  if string.sub(mark, 1, 1) == "@" then
    ClientInstance:notifyUI("SetBanner", jsonData)
  end
end

fk.client_callback["SetCardMark"] = function(jsonData)
  -- jsonData: [ int id, string mark, int value ]
  local data = json.decode(jsonData)
  local card, mark, value = data[1], data[2], data[3]
  Fk:getCardById(card):setMark(mark, value)

  ClientInstance:notifyUI("UpdateCard", tostring(card))
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

  local skill = Fk.skills[skill_name]
  if not skill or skill.frequency == Skill.Quest then return end
  updateLimitSkill(playerid, Fk.skills[skill_name], player:usedSkillTimes(skill_name, Player.HistoryGame))
end

fk.client_callback["SetSkillUseHistory"] = function(jsonData)
  local data = json.decode(jsonData)
  local id, skill_name, time, scope = data[1], data[2], data[3], data[4]
  local player = ClientInstance:getPlayerById(id)
  player:setSkillUseHistory(skill_name, time, scope)

  local skill = Fk.skills[skill_name]
  if not skill or skill.frequency == Skill.Quest then return end
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

fk.client_callback["ChangeSelf"] = function(jsonData)
  local data = json.decode(jsonData)
  ClientInstance:getPlayerById(data.id).player_cards[Player.Hand] = data.handcards
  ClientInstance:getPlayerById(data.id).special_cards = data.special_cards
  ClientInstance:notifyUI("ChangeSelf", data.id)
end

fk.client_callback["UpdateQuestSkillUI"] = function(jsonData)
  local data = json.decode(jsonData)
  local player, skillName, usedTimes = data[1], data[2], data[3]
  updateLimitSkill(player, Fk.skills[skillName], usedTimes)
end

fk.client_callback["UpdateGameData"] = function(jsonData)
  local data = json.decode(jsonData)
  local player, total, win, run = data[1], data[2], data[3], data[4]
  player = ClientInstance:getPlayerById(player)
  if player then
    player.player:setGameData(total, win, run)
  end

  ClientInstance:notifyUI("UpdateGameData", jsonData)
end

fk.client_callback["AddTotalGameTime"] = function(jsonData)
  local data = json.decode(jsonData)
  local player, time = data[1], data[2]
  player = ClientInstance:getPlayerById(player)
  if player then
    player.player:addTotalGameTime(time)
    if player == Self then
      ClientInstance:notifyUI("AddTotalGameTime", jsonData)
    end
  end
end

fk.client_callback["StartGame"] = function(jsonData)
  local c = ClientInstance
  c.record = {
    fk.FK_VER,
    os.date("%Y%m%d%H%M%S"),
    c.enter_room_data,
    json.encode { Self.id, fk.Self:getScreenName(), fk.Self:getAvatar() },
    -- RESERVED
    "",
    "",
    "",
    "",
    "",
    "",
  }
  for _, p in ipairs(c.players) do
    if p.id ~= Self.id then
      table.insert(c.record, {
        math.floor(os.getms() / 1000),
        false,
        "AddPlayer",
        json.encode {
          p.player:getId(),
          p.player:getScreenName(),
          p.player:getAvatar(),
          true,
          p.player:getTotalGameTime(),
        },
      })
    end
  end
  c.recording = true
  c:notifyUI("StartGame", jsonData)
end

fk.client_callback["GameOver"] = function(jsonData)
  local c = ClientInstance
  if c.recording then
    c.recording = false
    c.record[2] = table.concat({
      c.record[2],
      Self.player:getScreenName(),
      c.room_settings.gameMode,
      Self.general,
      Self.role,
      jsonData,
    }, ".")
    -- c.client:saveRecord(json.encode(c.record), c.record[2])
  end
  c:notifyUI("GameOver", jsonData)
end

fk.client_callback["EnterLobby"] = function(jsonData)
  local c = ClientInstance
  --[[
  if c.recording and not c.observing then
    c.recording = false
    c.record[2] = table.concat({
      c.record[2],
      Self.player:getScreenName(),
      c.room_settings.gameMode,
      Self.general,
      Self.role,
      "",
    }, ".")
    -- c.client:saveRecord(json.encode(c.record), c.record[2])
  end
  --]]
  c:notifyUI("EnterLobby", jsonData)
end

fk.client_callback["PrintCard"] = function(j)
  local data = json.decode(j)
  local n, s, num = table.unpack(data)
  local cd = Fk:cloneCard(n, s, num)
  Fk:_addPrintedCard(cd)
end

fk.client_callback["AddBuddy"] = function(j)
  local c = ClientInstance
  local data = json.decode(j)
  local id, hand = table.unpack(data)
  local to = c:getPlayerById(id)
  Self:addBuddy(to)
  to.player_cards[Player.Hand] = hand
end

fk.client_callback["RmBuddy"] = function(j)
  local c = ClientInstance
  local id = tonumber(j)
  local to = c:getPlayerById(id)
  Self:removeBuddy(to)
  to.player_cards[Player.Hand] = table.map(to.player_cards, function() return -1 end)
end

-- Create ClientInstance (used by Lua)
ClientInstance = Client:new()
dofile "lua/client/client_util.lua"
