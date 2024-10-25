-- SPDX-License-Identifier: GPL-3.0-or-later

---@class Client : AbstractRoom
---@field public client fk.Client
---@field public players ClientPlayer[] @ 所有参战玩家的数组
---@field public alive_players ClientPlayer[] @ 所有存活玩家的数组
---@field public observers ClientPlayer[] @ 观察者的数组
---@field public current ClientPlayer @ 当前回合玩家
---@field public observing boolean
---@field public record any
---@field public last_update_ui integer @ 上次刷新状态技UI的时间
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

-- 无需进行JSON.parse，但可能传入JSON字符串的command
local no_decode_commands = {
  "ErrorMsg",
  "ErrorDlg",
  "Heartbeat",
}

function Client:initialize()
  AbstractRoom.initialize(self)
  self.client = fk.ClientInstance
  self.notifyUI = function(_, command, data)
    fk.Backend:notifyUI(command, data)
  end
  self.client.callback = function(_self, command, jsonData, isRequest)
    if self.recording then
      table.insert(self.record, {math.floor(os.getms() / 1000), isRequest, command, jsonData})
    end

    local cb = fk.client_callback[command]
    local data
    if table.contains(no_decode_commands, command) then
      data = jsonData
    else
      local err, ret = pcall(json.decode, jsonData)
      if err == false then
        -- 不关心报错
        data = jsonData
      else
        data = ret
      end
    end

    if table.contains(pattern_refresh_commands, command) then
      Fk.currentResponsePattern = nil
      Fk.currentResponseReason = nil
    end

    if (type(cb) == "function") then
      cb(data)
    else
      self:notifyUI(command, data)
    end

    if self.recording and command == "GameLog" then
      --and os.getms() - self.last_update_ui > 60000 then
      -- self.last_update_ui = os.getms()
      -- TODO: create a function
      -- 刷所有人手牌上限
      for _, p in ipairs(self.alive_players) do
        self:notifyUI("MaxCard", {
          pcardMax = p:getMaxCards(),
          id = p.id,
        })
      end
      -- 刷自己的手牌
      for _, cid in ipairs(Self:getCardIds("h")) do
        self:notifyUI("UpdateCard", cid)
      end
      -- 刷技能状态
      self:notifyUI("UpdateSkill", nil)
    end
  end

  self.disabled_packs = {}
  self.disabled_generals = {}
  -- self.last_update_ui = os.getms()

  self.recording = false
end

---@param id integer
---@return ClientPlayer
function Client:getPlayerById(id)
  if id == Self.id then return Self end
  for _, p in ipairs(self.players) do
    if p.id == id then return p end
  end
  return nil
end

---@param moves CardsMoveStruct[]
function Client:moveCards(moves)
  for _, data in ipairs(moves) do
    if #data.moveInfo > 0 then
      for _, info in ipairs(data.moveInfo) do
        self:applyMoveInfo(data, info)
        Fk:filterCard(info.cardId, self:getPlayerById(data.to))
      end
    end
  end
end

---@param msg LogMessage
local function parseMsg(msg, nocolor, visible_data)
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
    local known = id ~= -1
    if visible_data then known = visible_data[tostring(id)] end
    if known then
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
      local known = id ~= -1
      if visible_data then known = visible_data[tostring(id)] end
      if known then
        table.insert(card_str, Fk:getCardById(id, true):toLogString())
      end
    end
    if unknownCount > 0 then
      local suffix = unknownCount > 1 and ("x" .. unknownCount) or ""
      table.insert(card_str, Fk:translate("unknown_card") .. suffix)
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
function Client:appendLog(msg, visible_data)
  local text = parseMsg(msg, nil, visible_data)
  self:notifyUI("GameLog", text)
  if msg.toast then
    self:notifyUI("ShowToast", text)
  end
end

---@param msg LogMessage
function Client:setCardNote(ids, msg)
  for _, id in ipairs(ids) do
    if id ~= -1 then
      self:notifyUI("SetCardFootnote", { id, parseMsg(msg, true) })
    end
  end
end

fk.client_callback["SetCardFootnote"] = function(data)
  ClientInstance:setCardNote(data[1], data[2]);
end

local function setup(id, name, avatar)
  local self = fk.Self
  self:setId(id)
  self:setScreenName(name)
  self:setAvatar(avatar)
  Self = ClientPlayer:new(fk.Self)
end

fk.client_callback["Setup"] = function(data)
  -- jsonData: [ int id, string screenName, string avatar ]
  local id, name, avatar = data[1], data[2], data[3]
  setup(id, name, avatar)
end

fk.client_callback["EnterRoom"] = function(_data)
  Self = ClientPlayer:new(fk.Self)
  -- FIXME: 需要改Qml
  local ob = ClientInstance.observing
  ClientInstance = Client:new() -- clear old client data
  ClientInstance.observing = ob
  ClientInstance.players = {Self}
  ClientInstance.alive_players = {Self}
  ClientInstance.discard_pile = {}

  local data = _data[3]
  ClientInstance.enter_room_data = json.encode(_data);
  ClientInstance.room_settings = data
  table.insertTableIfNeed(
    data.disabledPack,
    Fk.game_mode_disabled[data.gameMode]
  )
  ClientInstance.disabled_packs = data.disabledPack
  ClientInstance.disabled_generals = data.disabledGenerals
  ClientInstance:notifyUI("EnterRoom", _data)
end

fk.client_callback["AddPlayer"] = function(data)
  -- jsonData: [ int id, string screenName, string avatar ]
  -- when other player enter the room, we create clientplayer(C and lua) for them
  local id, name, avatar, time = data[1], data[2], data[3], data[5]
  local player = fk.ClientInstance:addPlayer(id, name, avatar)
  player:addTotalGameTime(time or 0) -- 以防再次智迟
  local p = ClientPlayer:new(player)
  table.insert(ClientInstance.players, p)
  table.insert(ClientInstance.alive_players, p)
  ClientInstance:notifyUI("AddPlayer", data)
end

fk.client_callback["RemovePlayer"] = function(data)
  -- jsonData: [ int id ]
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
    ClientInstance:notifyUI("RemovePlayer", data)
  end
end

fk.client_callback["AddObserver"] = function(data)
  -- jsonData: [ int id, string screenName, string avatar ]
  -- when observer enter the room, we create lua clientplayer for them
  local id, name, avatar = data[1], data[2], data[3]
  local player = {
    getId = function() return id end,
    getScreenName = function() return name end,
    getAvatar = function() return avatar end,
  }
  local p = ClientPlayer:new(player)
  table.insert(ClientInstance.observers, p)
  -- ClientInstance:notifyUI("ServerMessage", string.format(Fk:translate("$AddObserver"), name))
end

fk.client_callback["RemoveObserver"] = function(data)
  local id = data[1]
  for _, p in ipairs(ClientInstance.observers) do
    if p.player:getId() == id then
      table.removeOne(ClientInstance.observers, p)
      -- ClientInstance:notifyUI("ServerMessage", string.format(Fk:translate("$RemoveObserver"), p.player:getScreenName()))
      break
    end
  end
end

fk.client_callback["ArrangeSeats"] = function(data)
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

  ClientInstance:notifyUI("ArrangeSeats", data)
end

fk.client_callback["PropertyUpdate"] = function(data)
  -- jsonData: [ int id, string property_name, value ]
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

  ClientInstance:notifyUI("PropertyUpdate", data)
end

fk.client_callback["PlayCard"] = function(data)
  local h = Fk.request_handlers["PlayCard"]:new(Self)
  h.change = {}
  h:setup()
  h.scene:notifyUI()
  ClientInstance:notifyUI("PlayCard", data)
end

fk.client_callback["AskForCardChosen"] = function(data)
  -- jsonData: [ int target_id, string flag, int reason ]
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
  ClientInstance:notifyUI("AskForCardChosen", ui_data)
end

fk.client_callback["AskForCardsChosen"] = function(data)
  -- jsonData: [ int target_id, int min, int max, string flag, int reason ]
  local id, min, max, flag, reason, prompt = table.unpack(data)
    --data[1], data[2], data[3], data[4], data[5], data[6]
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
  ClientInstance:notifyUI("AskForCardsChosen", ui_data)
end

--- separated moves to many moves(one card per move)
---@param moves CardsMoveStruct[]
local function separateMoves(moves)
  local ret = {}  ---@type CardsMoveInfo[]

  local function containArea(area, relevant, defaultVisible) --处理区的处理？
    local areas = relevant
      and {Card.PlayerEquip, Card.PlayerJudge, Card.PlayerHand}
      or {Card.PlayerEquip, Card.PlayerJudge}
    return table.contains(areas, area) or (defaultVisible and table.contains({Card.Processing, Card.DiscardPile}, area))
  end

  for _, move in ipairs(moves) do
    local singleVisible = move.moveVisible
    if not singleVisible then
      if move.visiblePlayers then
        local visiblePlayers = move.visiblePlayers
        if type(visiblePlayers) == "number" then
          if Self:isBuddy(visiblePlayers) then
            singleVisible = true
          end
        elseif type(visiblePlayers) == "table" then
          if table.find(visiblePlayers, function(pid) return Self:isBuddy(pid) end) then
            singleVisible = true
          end
        end
      else
        if move.to and move.toArea == Card.PlayerSpecial and Self:isBuddy(move.to) then
          singleVisible = true
        end
      end
    end
    if not singleVisible then
      singleVisible = containArea(move.toArea, move.to and Self:isBuddy(move.to), move.moveVisible == nil)
    end

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
        moveVisible = singleVisible or containArea(info.fromArea, move.from and Self:isBuddy(move.from), move.moveVisible == nil)
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

  if move.toArea == Card.PlayerHand then
    if move.fromArea == Card.PlayerSpecial then
      client:appendLog({
        type = "$GetCardsFromPile",
        from = move.to,
        arg = move.fromSpecialName,
        arg2 = #move.ids,
        card = move.ids,
      }, visible_data)
    elseif move.fromArea == Card.DrawPile then
      client:appendLog({
        type = "$DrawCards",
        from = move.to,
        card = move.ids,
        arg = #move.ids,
      }, visible_data)
    elseif move.fromArea == Card.Processing then
      client:appendLog({
        type = "$GotCardBack",
        from = move.to,
        card = move.ids,
        arg = #move.ids,
      }, visible_data)
    elseif move.fromArea == Card.DiscardPile then
      client:appendLog({
        type = "$RecycleCard",
        from = move.to,
        card = move.ids,
        arg = #move.ids,
      }, visible_data)
    elseif move.from then
      client:appendLog({
        type = "$MoveCards",
        from = move.from,
        to = { move.to },
        arg = #move.ids,
        card = move.ids,
      }, visible_data)
    else
      client:appendLog({
        type = "$PreyCardsFromPile",
        from = move.to,
        card = move.ids,
        arg = #move.ids,
      }, visible_data)
    end
  elseif move.toArea == Card.PlayerEquip then
    client:appendLog({
      type = "$InstallEquip",
      from = move.to,
      card = move.ids,
    }, visible_data)
  elseif move.toArea == Card.PlayerJudge then
    if move.from ~= move.to and move.fromArea == Card.PlayerJudge then
      client:appendLog({
        type = "$LightningMove",
        from = move.from,
        to = { move.to },
        card = move.ids,
      }, visible_data)
    elseif move.from then
      client:appendLog({
        type = "$PasteCard",
        from = move.from,
        to = { move.to },
        card = move.ids,
      }, visible_data)
    end
  elseif move.toArea == Card.PlayerSpecial then
    client:appendLog({
      type = "$AddToPile",
      arg = move.specialName,
      arg2 = #move.ids,
      from = move.to,
      card = move.ids,
    }, visible_data)
  elseif move.fromArea == Card.PlayerEquip then
    client:appendLog({
      type = "$UninstallEquip",
      from = move.from,
      card = move.ids,
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
          card = move.ids,
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
      card = move.ids,
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
          card = move.ids,
          arg = #move.ids,
        }, visible_data)
      else
        client:appendLog({
          type = "$DiscardCards",
          from = move.from,
          card = move.ids,
          arg = #move.ids,
        }, visible_data)
      end
    elseif move.moveReason == fk.ReasonPutIntoDiscardPile then
      client:appendLog({
        type = "$PutToDiscard",
        card = move.ids,
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

---@param raw_moves CardsMoveStruct[]
fk.client_callback["MoveCards"] = function(raw_moves)
  -- jsonData: CardsMoveStruct[]
  ClientInstance:moveCards(raw_moves)
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
  ClientInstance:notifyUI("MoveCards", visible_data)
  for _, move in ipairs(merged) do
    sendMoveCardLog(move, visible_data)
  end
end

fk.client_callback["ShowCard"] = function(data)
  local from = data.from
  local cards = data.cards
  ClientInstance:notifyUI("MoveCards", {
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
    ClientInstance:notifyUI("UpdateLimitSkill", { pid, skill.switchSkillName, _times })
  elseif skill.frequency == Skill.Limited or skill.frequency == Skill.Wake or skill.frequency == Skill.Quest then
    ClientInstance:notifyUI("UpdateLimitSkill", { pid, skill.name, times })
  end
end

fk.client_callback["LoseSkill"] = function(data)
  -- jsonData: [ int player_id, string skill_name ]
  local id, skill_name, fake = data[1], data[2], data[3]
  local target = ClientInstance:getPlayerById(id)
  local skill = Fk.skills[skill_name]

  if not fake then
    target:loseSkill(skill)
    if skill.visible then
      ClientInstance:notifyUI("LoseSkill", data)
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
      ClientInstance:notifyUI("LoseSkill", data)
    end

    local active = table.filter(sks, function(s)
      return s:isInstanceOf(ActiveSkill) or s:isInstanceOf(ViewAsSkill)
    end)

    if #active > 0 then
      chk = true
      ClientInstance:notifyUI("LoseSkill", {
        id, skill_name,
      })
    end

    if not chk then
      ClientInstance:notifyUI("LoseSkill", {
        id, skill_name,
      })
    end
  end

  updateLimitSkill(id, skill, -1)
end

fk.client_callback["AddSkill"] = function(data)
  -- jsonData: [ int player_id, string skill_name ]
  local id, skill_name, fake = data[1], data[2], data[3]
  local target = ClientInstance:getPlayerById(id)
  local skill = Fk.skills[skill_name]

  if not fake then
    target:addSkill(skill)
    if skill.visible then
      ClientInstance:notifyUI("AddSkill", data)
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
      ClientInstance:notifyUI("AddSkill", data)
    end

    local active = table.filter(sks, function(s)
      return s:isInstanceOf(ActiveSkill) or s:isInstanceOf(ViewAsSkill)
    end)

    if #active > 0 then
      chk = true
      ClientInstance:notifyUI("AddSkill", {
        id, skill_name,
      })
    end

    -- 面板上总得有点啥东西表明自己有技能吧 = =
    if not chk then
      ClientInstance:notifyUI("AddSkill", {
        id, skill_name,
      })
    end
  end

  if skill.frequency == Skill.Quest then
    return
  end

  updateLimitSkill(id, skill, target:usedSkillTimes(skill_name, Player.HistoryGame))
end

fk.client_callback["AskForSkillInvoke"] = function(data)
  -- jsonData: [ string name, string prompt ]

  local h = Fk.request_handlers["AskForSkillInvoke"]:new(Self)
  h.prompt = data[2]
  h.change = {}
  h:setup()
  h.scene:notifyUI()
  ClientInstance:notifyUI("AskForSkillInvoke", data)
end

fk.client_callback["AskForUseActiveSkill"] = function(data)
  -- jsonData: [ string skill_name, string prompt, bool cancelable. json extra_data ]
  local skill = Fk.skills[data[1]]
  local extra_data = data[4]
  skill._extra_data = extra_data

  Fk.currentResponseReason = extra_data.skillName
  local h = Fk.request_handlers["AskForUseActiveSkill"]:new(Self)
  h.skill_name = data[1]
  h.prompt     = data[2]
  h.cancelable = data[3]
  h.extra_data = data[4]
  h.change = {}
  h:setup()
  h.scene:notifyUI()
  ClientInstance:notifyUI("AskForUseActiveSkill", data)
end

fk.client_callback["AskForUseCard"] = function(data)
  -- jsonData: card, pattern, prompt, cancelable, {}
  Fk.currentResponsePattern = data[2]
  local h = Fk.request_handlers["AskForUseCard"]:new(Self)
  -- h.skill_name = data[1] (skill_name是给选中的视为技用的)
  h.pattern    = data[2]
  h.prompt     = data[3]
  h.cancelable = data[4]
  h.extra_data = data[5]
  h.change = {}
  h:setup()
  h.scene:notifyUI()
  ClientInstance:notifyUI("AskForUseCard", data)
end

fk.client_callback["AskForResponseCard"] = function(data)
  -- jsonData: card, pattern, prompt, cancelable, {}
  Fk.currentResponsePattern = data[2]
  local h = Fk.request_handlers["AskForResponseCard"]:new(Self)
  -- h.skill_name = data[1] (skill_name是给选中的视为技用的)
  h.pattern    = data[2]
  h.prompt     = data[3]
  h.cancelable = data[4]
  h.extra_data = data[5]
  h.change = {}
  h:setup()
  h.scene:notifyUI()
  ClientInstance:notifyUI("AskForResponseCard", data)
end

fk.client_callback["SetPlayerMark"] = function(data)
  -- jsonData: [ int id, string mark, int value ]
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
        if text == "#hidden" then data[3] = 0 end
      end
    end
    ClientInstance:notifyUI("SetPlayerMark", data)
  end
end

fk.client_callback["SetBanner"] = function(data)
  -- jsonData: [ int id, string mark, int value ]
  local mark, value = data[1], data[2]
  ClientInstance:setBanner(mark, value)

  if string.sub(mark, 1, 1) == "@" then
    ClientInstance:notifyUI("SetBanner", data)
  end
end

fk.client_callback["SetCardMark"] = function(data)
  -- jsonData: [ int id, string mark, int value ]
  local card, mark, value = data[1], data[2], data[3]
  Fk:getCardById(card):setMark(mark, value)

  ClientInstance:notifyUI("UpdateCard", card)
end

fk.client_callback["Chat"] = function(data)
  -- jsonData: { int type, int sender, string msg }
  if data.type == 1 then
    data.general = ""
    data.time = os.date("%H:%M:%S")
    ClientInstance:notifyUI("Chat", data)
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
  ClientInstance:notifyUI("Chat", data)
end

fk.client_callback["GameLog"] = function(data)
  ClientInstance:appendLog(data)
end

fk.client_callback["LogEvent"] = function(data)
  if data.type == "Death" then
    table.removeOne(
      ClientInstance.alive_players,
      ClientInstance:getPlayerById(data.to)
    )
  end
  ClientInstance:notifyUI("LogEvent", data)
end

fk.client_callback["AddCardUseHistory"] = function(data)
  Self:addCardUseHistory(data[1], data[2])
end

fk.client_callback["SetCardUseHistory"] = function(data)
  Self:setCardUseHistory(data[1], data[2], data[3])
end

fk.client_callback["AddSkillUseHistory"] = function(data)
  local playerid, skill_name, time = data[1], data[2], data[3]
  local player = ClientInstance:getPlayerById(playerid)
  player:addSkillUseHistory(skill_name, time)

  local skill = Fk.skills[skill_name]
  if not skill or skill.frequency == Skill.Quest then return end
  updateLimitSkill(playerid, Fk.skills[skill_name], player:usedSkillTimes(skill_name, Player.HistoryGame))
end

fk.client_callback["SetSkillUseHistory"] = function(data)
  local id, skill_name, time, scope = data[1], data[2], data[3], data[4]
  local player = ClientInstance:getPlayerById(id)
  player:setSkillUseHistory(skill_name, time, scope)

  local skill = Fk.skills[skill_name]
  if not skill or skill.frequency == Skill.Quest then return end
  updateLimitSkill(id, Fk.skills[skill_name], player:usedSkillTimes(skill_name, Player.HistoryGame))
end

fk.client_callback["AddVirtualEquip"] = function(data)
  local cname = data.name
  local player = ClientInstance:getPlayerById(data.player)
  local subcards = data.subcards
  local c = Fk:cloneCard(cname)
  c:addSubcards(subcards)
  player:addVirtualEquip(c)
end

fk.client_callback["RemoveVirtualEquip"] = function(data)
  local player = ClientInstance:getPlayerById(data.player)
  player:removeVirtualEquip(data.id)
end

fk.client_callback["Heartbeat"] = function()
  ClientInstance.client:notifyServer("Heartbeat", "")
end

fk.client_callback["ChangeSelf"] = function(data)
  local pid = tonumber(data)
  local c = ClientInstance
  c.client:changeSelf(pid) -- for qml
  Self = c:getPlayerById(pid)
  ClientInstance:notifyUI("ChangeSelf", pid)
end

fk.client_callback["UpdateQuestSkillUI"] = function(data)
  local player, skillName, usedTimes = data[1], data[2], data[3]
  updateLimitSkill(player, Fk.skills[skillName], usedTimes)
end

fk.client_callback["UpdateGameData"] = function(data)
  local player, total, win, run = data[1], data[2], data[3], data[4]
  player = ClientInstance:getPlayerById(player)
  if player then
    player.player:setGameData(total, win, run)
  end

  ClientInstance:notifyUI("UpdateGameData", data)
end

fk.client_callback["AddTotalGameTime"] = function(data)
  local player, time = data[1], data[2]
  player = ClientInstance:getPlayerById(player)
  if player then
    player.player:addTotalGameTime(time)
    if player == Self then
      ClientInstance:notifyUI("AddTotalGameTime", data)
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
  ---[[
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

fk.client_callback["PrintCard"] = function(data)
  local n, s, num = table.unpack(data)
  ClientInstance:printCard(n, s, num)
end

fk.client_callback["AddBuddy"] = function(data)
  local c = ClientInstance
  local fromid, id = table.unpack(data)
  local from = c:getPlayerById(fromid)
  local to = c:getPlayerById(id)
  from:addBuddy(to)
end

fk.client_callback["RmBuddy"] = function(data)
  local c = ClientInstance
  local fromid, id = table.unpack(data)
  local from = c:getPlayerById(fromid)
  local to = c:getPlayerById(id)
  from:removeBuddy(to)
end

local function loadRoomSummary(data)
  local players = data.players

  fk.client_callback["StartGame"]("")

  for _, pid in ipairs(data.circle) do
    if pid ~= data.you then
      fk.client_callback["AddPlayer"](players[tostring(pid)].setup_data)
    end
  end

  fk.client_callback["ArrangeSeats"](data.circle)

  ClientInstance:loadJsonObject(data) -- 此处已同步全部数据 剩下就是更新UI

  for k, v in pairs(ClientInstance.banners) do
    if k[1] == "@" then
      ClientInstance:notifyUI("SetBanner", { k, v })
    end
  end

  for _, p in ipairs(ClientInstance.players) do p:sendDataToUI() end

  ClientInstance:notifyUI("UpdateDrawPile", #ClientInstance.draw_pile)
  ClientInstance:notifyUI("UpdateRoundNum", data.round_count)
end

fk.client_callback["Reconnect"] = function(data)
  local players = data.players

  local setup_data = players[tostring(data.you)].setup_data
  setup(setup_data[1], setup_data[2], setup_data[3])
  fk.client_callback["AddTotalGameTime"]{ setup_data[1], setup_data[5] }

  local enter_room_data = { data.timeout, data.settings }
  table.insert(enter_room_data, 1, #data.circle)
  fk.client_callback["EnterLobby"]("")
  fk.client_callback["EnterRoom"](enter_room_data)

  loadRoomSummary(data)
end

fk.client_callback["Observe"] = function(data)
  local players = data.players

  local setup_data = players[tostring(data.you)].setup_data
  setup(setup_data[1], setup_data[2], setup_data[3])

  local enter_room_data = { data.timeout, data.settings }
  table.insert(enter_room_data, 1, #data.circle)
  fk.client_callback["EnterRoom"](enter_room_data)

  loadRoomSummary(data)
end

fk.client_callback["PrepareDrawPile"] = function(data)
  local seed = tonumber(data)
  ClientInstance:prepareDrawPile(seed)
end

fk.client_callback["ShuffleDrawPile"] = function(data)
  local seed = tonumber(data)
  ClientInstance:shuffleDrawPile(seed)
end

-- Create ClientInstance (used by Lua)
ClientInstance = Client:new()
dofile "lua/client/client_util.lua"

if FileIO.pwd():endsWith("packages/freekill-core") then
  FileIO.cd("../..")
end
