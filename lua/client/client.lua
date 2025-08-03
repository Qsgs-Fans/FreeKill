-- SPDX-License-Identifier: GPL-3.0-or-later

---@class Client : AbstractRoom
---@field public client fk.Client
---@field public players ClientPlayer[] @ 所有参战玩家的数组
---@field public alive_players ClientPlayer[] @ 所有存活玩家的数组
---@field public observers ClientPlayer[] @ 观察者的数组
---@field public current ClientPlayer @ 当前回合玩家
---@field public observing boolean 客户端是否在旁观
---@field public replaying boolean 客户端是否在重放
---@field public replaying_show boolean 重放时是否要看到全部牌
---@field public record any
---@field public last_update_ui integer @ 上次刷新状态技UI的时间
Client = AbstractRoom:subclass('Client')

-- load client classes
ClientPlayer = require "client.clientplayer"

---@type table<string, fun(self: Client, data: any)>
fk.client_callback = {}

-- 总而言之就是会让roomScene.state变为responding或者playing的状态
local pattern_refresh_commands = {
  "PlayCard",
  "AskForUseActiveSkill",
  "AskForUseCard",
  "AskForResponseCard",
}

-- 传了个string且不知道为什么不走cbor.decode的
local no_decode_commands = {
  "ErrorMsg",
  "ErrorDlg",
  "Heartbeat",
  "ServerMessage",

  "UpdateAvatar",
  "UpdatePassword",
}

ClientCallback = function(_self, command, jsonData, isRequest)
  local self = ClientInstance
  if self.recording then
    table.insert(self.record, {math.floor(os.getms() / 1000), isRequest, command, jsonData})
  end

  -- CBOR调试中。。。
  -- print(command, jsonData:gsub(".", function(c) return ("%02x"):format(c:byte()) end))

  local cb = fk.client_callback[command]
  local data
  if table.contains(no_decode_commands, command) then
    data = jsonData
  else
    data = cbor.decode(jsonData)
  end

  if table.contains(pattern_refresh_commands, command) then
    Fk.currentResponsePattern = nil
    Fk.currentResponseReason = nil
  end

  if (type(cb) == "function") then
    if command:startsWith("AskFor") or command == "PlayCard" then
      self:notifyUI("CancelRequest") -- 确保变成notactive 防止卡双active 权宜之计
    end
    cb(self, data)
  else
    self:notifyUI(command, data)
  end
end

function Client:initialize(_client)
  AbstractRoom.initialize(self)
  self.client = _client

  self.disabled_packs = {}
  self.disabled_generals = {}
  -- self.last_update_ui = os.getms()
  -- FIXME 0.5.8扬了这个
  self.event_stack_logs = {}

  self.recording = false
end

function Client:notifyUI(command, data)
  self.client:notifyUI(command, data)
end

function Client:startRecording()
  if self.recording then return end
  if self.replaying then return end
  self.record = {
    fk.FK_VER,
    os.date("%Y%m%d%H%M%S"),
    self.enter_room_data,
    cbor.encode { Self.id, Self.player:getScreenName(), Self.player:getAvatar() },
    "normal", -- 表示本录像是正常全流程，还是重连，还是旁观
    -- RESERVED
    "",
    "",
    "",
    "",
    "",
  }
  for _, p in ipairs(self.players) do
    if p.id ~= Self.id then
      table.insert(self.record, {
        math.floor(os.getms() / 1000),
        false,
        "AddPlayer",
        cbor.encode {
          p.player:getId(),
          p.player:getScreenName(),
          p.player:getAvatar(),
          true,
          p.player:getTotalGameTime(),
        },
      })
    end
  end
  self.recording = true
end

function Client:stopRecording(jsonData)
  if not self.recording then return end
  self.record[2] = table.concat({
    self.record[2],
    Self.player:getScreenName():gsub("%.", "%%2e"),
    self.settings.gameMode,
    Self.general,
    Self.role,
    jsonData,
  }, ".")
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

---@param seat integer
---@return ClientPlayer
function Client:getPlayerBySeat(seat)
  if seat == Self.seat then return Self end
  for _, p in ipairs(self.players) do
    if p.seat == seat then return p end
  end
  return nil
end

---@param moves MoveCardsData[]
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

function Client:toJsonObject()
  local o = AbstractRoom.toJsonObject(self)
  o.you = Self.id
  return o
end

fk.client_callback["SetCardFootnote"] = function(self, data)
  self:setCardNote(data[1], data[2]);
end

fk.client_callback["NetworkDelayTest"] = function(self, data)
  self.client:sendSetupPacket(data)
end

fk.client_callback["InstallKey"] = function(self)
  self.client:installMyAESKey()
end

function Client:setup(id, name, avatar, msec)
  local self_player = self.client:getSelf()
  self_player:setId(id)
  self_player:setScreenName(name)
  self_player:setAvatar(avatar)
  Self = ClientPlayer:new(self_player)
  if msec then
    self.client:setupServerLag(msec)
  end
end

fk.client_callback["Setup"] = function(self, data)
  -- jsonData: [ int id, string screenName, string avatar ]
  local id, name, avatar, msec = data[1], data[2], data[3], data[4]
  self:setup(id, name, avatar, msec)
end

function Client:enterRoom(_data)
  Self = ClientPlayer:new(self.client:getSelf())
  -- FIXME: 需要改Qml
  local ob = self.observing
  local replaying = self.replaying
  local showcards = self.replaying_show
  local recording = self.recording
  self:initialize(self.client) -- clear old client data
  self.observing = ob
  self.replaying = replaying
  self.replaying_show = showcards
  self.recording = recording -- 重连/旁观的录像后面那段EnterRoom会触发该函数

  -- FIXME: 应该在C++中修改，这种改法错大发了
  -- FIXME: C++中加入房间时需要把Self也纳入players列表
  local sp = Self.player
  self.client:addPlayer(sp:getId(), sp:getScreenName(), sp:getAvatar())
  self.players = {Self}
  self.alive_players = {Self}

  local data = _data[3]
  self.enter_room_data = cbor.encode(_data);
  -- 补一个，防止爆炸
  if self.recording then
    self.record[3] = self.enter_room_data
  end
  self.timeout = _data[2]
  self.capacity = _data[1]
  self.settings = data
  table.insertTableIfNeed(
    data.disabledPack,
    Fk.game_mode_disabled[data.gameMode]
  )
  self.disabled_packs = data.disabledPack
  self.disabled_generals = data.disabledGenerals
end

fk.client_callback["EnterRoom"] = function(self, data)
  self:enterRoom(data)
  self:notifyUI("EnterRoom", data)
end

function Client:addPlayer(id, name, avatar, time)
  local player = self.client:addPlayer(id, name, avatar)
  player:addTotalGameTime(time or 0)
  local p = ClientPlayer:new(player)
  table.insert(self.players, p)
  table.insert(self.alive_players, p)
end

fk.client_callback["AddPlayer"] = function(self, data)
  -- jsonData: [ int id, string screenName, string avatar ]
  -- when other player enter the room, we create clientplayer(C and lua) for them
  local id, name, avatar, time = data[1], data[2], data[3], data[5]
  self:addPlayer(id, name, avatar, time)
  self:notifyUI("AddPlayer", data)
end

function Client:removePlayer(id)
  for _, p in ipairs(self.players) do
    if p.player:getId() == id then
      table.removeOne(self.players, p)
      table.removeOne(self.alive_players, p)
      break
    end
  end
end

fk.client_callback["RemovePlayer"] = function(self, data)
  -- jsonData: [ int id ]
  local id = data[1]
  self:removePlayer(id)
  if id ~= Self.id then
    self.client:removePlayer(id)
    self:notifyUI("RemovePlayer", data)
  end
end

function Client:addObserver(id, name, avatar)
  local player = {
    getId = function() return id end,
    getScreenName = function() return name end,
    getAvatar = function() return avatar end,
  }
  local p = ClientPlayer:new(player)
  table.insert(self.observers, p)
  -- self:notifyUI("ServerMessage", string.format(Fk:translate("$AddObserver"), name))
end

fk.client_callback["AddObserver"] = function(self, data)
  -- jsonData: [ int id, string screenName, string avatar ]
  -- when observer enter the room, we create lua clientplayer for them
  local id, name, avatar = data[1], data[2], data[3]
  self:addObserver(id, name, avatar)
end

function Client:removeObserver(id)
  for _, p in ipairs(self.observers) do
    if p.player:getId() == id then
      table.removeOne(self.observers, p)
      -- self:notifyUI("ServerMessage", string.format(Fk:translate("$RemoveObserver"), p.player:getScreenName()))
      break
    end
  end
end

fk.client_callback["RemoveObserver"] = function(self, data)
  local id = data[1]
  self:removeObserver(id)
end

function Client:arrangeSeats(player_circle)
  local n = #self.players
  local players = {}

  for i = 1, n do
    local p = self:getPlayerById(player_circle[i])
    p.seat = i
    table.insert(players, p)
  end

  for i = 1, #players - 1 do
    players[i].next = players[i + 1]
  end
  players[#players].next = players[1]

  self.players = players

  self:notifyUI("ArrangeSeats", player_circle)
end

fk.client_callback["ArrangeSeats"] = Client.arrangeSeats

function Client:setPlayerProperty(player, property, value)
  player[property] = value

  if property == "dead" then
    if value == true then
      table.removeOne(self.alive_players, player)
    else
      table.insertIfNeed(self.alive_players, player)
    end
  end
end

fk.client_callback["PropertyUpdate"] = function(self, data)
  -- jsonData: [ int id, string property_name, value ]
  local id, name, value = data[1], data[2], data[3]
  local p = self:getPlayerById(id)
  self:setPlayerProperty(p, name, value)
  self:notifyUI("PropertyUpdate", data)
end

fk.client_callback["PlayCard"] = function(self, data)
  local h = Fk.request_handlers["PlayCard"]:new(Self)
  h.change = {}; h:setup(); h.scene:notifyUI()
  self:notifyUI("PlayCard", data)
end

fk.client_callback["AskForCardChosen"] = function(self, data)
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

fk.client_callback["AskForCardsChosen"] = function(self, data)
  -- jsonData: [ int target_id, int min, int max, string flag, int reason ]
  local id, min, max, flag, reason, prompt = table.unpack(data)
    --data[1], data[2], data[3], data[4], data[5], data[6]
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
      _min = min,
      _max = max,
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
    ui_data._min = min
    ui_data._max = max
    ui_data._reason = reason
    ui_data._prompt = prompt
  end
  self:notifyUI("AskForCardsChosen", ui_data)
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
fk.client_callback["MoveCards"] = function(self, raw_moves)
  -- jsonData: CardsMoveStruct[]
  self:moveCards(raw_moves)
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
  self:notifyUI("MoveCards", visible_data)
  for _, move in ipairs(merged) do
    sendMoveCardLog(move, visible_data)
  end
end

fk.client_callback["ShowCard"] = function(self, data)
  -- local from = data.from
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
  self:notifyUI("MoveCards", vdata)
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

fk.client_callback["LoseSkill"] = function(self, data)
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

fk.client_callback["AddSkill"] = function(self, data)
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

fk.client_callback["AddStatusSkill"] = function(self, data)
  -- jsonData: [ string skill_name ]
  local skill_name = data[1]
  local skill = Fk.skills[skill_name]
  self.status_skills[skill.class] = self.status_skills[skill.class] or {}
  table.insertIfNeed(self.status_skills[skill.class], skill)
end

fk.client_callback["AskForSkillInvoke"] = function(self, data)
  -- jsonData: [ string name, string prompt ]

  local h = Fk.request_handlers["AskForSkillInvoke"]:new(Self)
  h.prompt = data[2]
  h.change = {}
  h:setup()
  h.scene:notifyUI()
  self:notifyUI("AskForSkillInvoke", data)
end

fk.client_callback["AskForUseActiveSkill"] = function(self, data)
  -- jsonData: [ string skill_name, string prompt, bool cancelable. json extra_data ]
  local skill = Fk.skills[data[1]]
  local extra_data = data[4]
  skill._extra_data = extra_data
  Fk.currentResponseReason = extra_data.skillName

  local h = Fk.request_handlers["AskForUseActiveSkill"]:new(Self, data)
  h.change = {}
  h:setup()
  h.scene:notifyUI()
  self:notifyUI("AskForUseActiveSkill", data)
end

fk.client_callback["AskForUseCard"] = function(self, data)
  -- jsonData: card, pattern, prompt, cancelable, {}
  Fk.currentResponsePattern = data[2]
  local h = Fk.request_handlers["AskForUseCard"]:new(Self, data)
  h.change = {}
  h:setup()
  h.scene:notifyUI()
  self:notifyUI("AskForUseCard", data)
end

fk.client_callback["AskForResponseCard"] = function(self, data)
  -- jsonData: card, pattern, prompt, cancelable, {}
  Fk.currentResponsePattern = data[2]
  local h = Fk.request_handlers["AskForResponseCard"]:new(Self, data)
  h.change = {}
  h:setup()
  h.scene:notifyUI()
  self:notifyUI("AskForResponseCard", data)
end

fk.client_callback["SetPlayerMark"] = function(self, data)
  -- jsonData: [ int id, string mark, int value ]
  local player, mark, value = data[1], data[2], data[3]
  local p = self:getPlayerById(player)
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
    self:notifyUI("SetPlayerMark", data)
  end
end

fk.client_callback["SetBanner"] = function(self, data)
  -- jsonData: [ int id, string mark, int value ]
  local mark, value = data[1], data[2]
  self:setBanner(mark, value)

  if string.sub(mark, 1, 1) == "@" then
    self:notifyUI("SetBanner", data)
  end
end

fk.client_callback["SetCurrent"] = function(self, data)
  -- jsonData: [ int id ]
  local playerId = data[1]
  self:setCurrent(self:getPlayerById(playerId))
end

fk.client_callback["SetCardMark"] = function(self, data)
  -- jsonData: [ int id, string mark, int value ]
  local card, mark, value = data[1], data[2], data[3]
  Fk:getCardById(card):setMark(mark, value)

  self:notifyUI("UpdateCard", card)
end

fk.client_callback["Chat"] = function(self, data)
  -- jsonData: { int type, int sender, string msg }
  if data.type == 1 then
    data.general = ""
    data.time = os.date("%H:%M:%S")
    self:notifyUI("Chat", data)
    return
  end

  local p = self:getPlayerById(data.sender)
  if not p then
    for _, pl in ipairs(self.observers) do
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
  self:notifyUI("Chat", data)
end

fk.client_callback["GameLog"] = Client.appendLog

fk.client_callback["LogEvent"] = function(self, data)
  if data.type == "Death" then
    table.removeOne(
      self.alive_players,
      self:getPlayerById(data.to)
    )
  end
  self:notifyUI("LogEvent", data)
end

fk.client_callback["AddCardUseHistory"] = function(self, data)
  local playerid, card_name, num = table.unpack(data)
  local player = self:getPlayerById(playerid)
  player:addCardUseHistory(card_name, num)
end

fk.client_callback["SetCardUseHistory"] = function(self, data)
  local playerid, card_name, num, scope = table.unpack(data)
  local player = self:getPlayerById(playerid)
  player:setCardUseHistory(card_name, num, scope)
end

fk.client_callback["AddSkillUseHistory"] = function(self, data)
  local playerid, skill_name, time = data[1], data[2], data[3]
  local player = self:getPlayerById(playerid)
  player:addSkillUseHistory(skill_name, time)

  local skill = Fk.skills[skill_name]
  if not skill then return end
  updateLimitSkill(playerid, Fk.skills[skill_name])
end

fk.client_callback["SetSkillUseHistory"] = function(self, data)
  local id, skill_name, time, scope = data[1], data[2], data[3], data[4]
  local player = self:getPlayerById(id)
  player:setSkillUseHistory(skill_name, time, scope)

  local skill = Fk.skills[skill_name]
  if not skill then return end
  updateLimitSkill(id, Fk.skills[skill_name])
end

fk.client_callback["AddVirtualEquip"] = function(self, data)
  local cname = data.name
  local player = self:getPlayerById(data.player)
  local subcards = data.subcards
  local c = Fk:cloneCard(cname)
  c:addSubcards(subcards)
  player:addVirtualEquip(c)
end

fk.client_callback["RemoveVirtualEquip"] = function(self, data)
  local player = self:getPlayerById(data.player)
  player:removeVirtualEquip(data.id)
end

fk.client_callback["Heartbeat"] = function(self)
  self.client:notifyServer("Heartbeat", "")
end

fk.client_callback["ChangeSelf"] = function(self, data)
  local pid = tonumber(data)
  self.client:changeSelf(pid) -- for qml
  Self = self:getPlayerById(pid)
  print(pid, Self, table.concat(table.map(self.players, tostring), ","))
  self:notifyUI("ChangeSelf", pid)
end

fk.client_callback["UpdateQuestSkillUI"] = function(self, data)
  local playerId, skillName = data[1], data[2]
  updateLimitSkill(playerId, Fk.skills[skillName])
end

fk.client_callback["UpdateGameData"] = function(self, data)
  local player, total, win, run = data[1], data[2], data[3], data[4]
  player = self:getPlayerById(player)
  if player then
    player.player:setGameData(total, win, run)
  end

  self:notifyUI("UpdateGameData", data)
end

fk.client_callback["AddTotalGameTime"] = function(self, data)
  local player, time = data[1], data[2]
  player = self:getPlayerById(player)
  if player then
    player.player:addTotalGameTime(time)
    if player == Self then
      self:notifyUI("AddTotalGameTime", data)
    end
  end
end

fk.client_callback["StartGame"] = function(self, jsonData)
  self:startRecording()
  self:notifyUI("StartGame", jsonData)
end

fk.client_callback["GameOver"] = function(self, jsonData)
  if self.recording then
    self:stopRecording(jsonData)
    if not self.observing and not self.replaying then
      local result
      local winner = jsonData
      if table.contains(winner:split("+"), Self.role) then
        result = 1
      elseif winner == "" then
        result = 3
      else
        result = 2
      end
      self.client:saveGameData(self.settings.gameMode, Self.general,
        Self.deputyGeneral or "", Self.role, result, self.record[2],
        cbor.encode(self:toJsonObject()), cbor.encode(self.record))
    end
  end
  Self.buddy_list = table.map(self.players, Util.IdMapper)
  self:notifyUI("GameOver", jsonData)
end

fk.client_callback["EnterLobby"] = function(self, jsonData)
  self:stopRecording("")
  self:notifyUI("EnterLobby", jsonData)
end

fk.client_callback["PrintCard"] = function(self, data)
  local n, s, num = table.unpack(data)
  self:printCard(n, s, num)
end

fk.client_callback["AddBuddy"] = function(self, data)
  local fromid, id = table.unpack(data)
  local from = self:getPlayerById(fromid)
  local to = self:getPlayerById(id)
  from:addBuddy(to)
end

fk.client_callback["RmBuddy"] = function(self, data)
  local fromid, id = table.unpack(data)
  local from = self:getPlayerById(fromid)
  local to = self:getPlayerById(id)
  from:removeBuddy(to)
end

---@param self Client
local function loadRoomSummary(self, data)
  local players = data.players

  for _, pid in ipairs(data.circle) do
    if pid ~= data.you then
      fk.client_callback["AddPlayer"](self, players[tostring(pid)].setup_data)
    end
  end

  fk.client_callback["ArrangeSeats"](self, data.circle)

  fk.client_callback["StartGame"](self, "")

  self:loadJsonObject(data) -- 此处已同步全部数据 剩下就是更新UI

  for k, v in pairs(self.banners) do
    if k[1] == "@" then
      self:notifyUI("SetBanner", { k, v })
    end
  end

  for _, p in ipairs(self.players) do p:sendDataToUI() end

  self:notifyUI("UpdateDrawPile", #self.draw_pile)
  self:notifyUI("UpdateRoundNum", data.round_count)
end

fk.client_callback["Reconnect"] = function(self, data)
  local players = data.players

  fk.client_callback["EnterLobby"](self, "")

  if not self.replaying then
    self:startRecording()
    self.record[5] = "reconnect"
    table.insert(self.record, {math.floor(os.getms() / 1000), false, "Reconnect", cbor.encode(data)})
  end

  local setup_data = players[tostring(data.you)].setup_data
  self:setup(setup_data[1], setup_data[2], setup_data[3])
  fk.client_callback["AddTotalGameTime"](self, { setup_data[1], setup_data[5] })

  local enter_room_data = { data.timeout, data.settings }
  table.insert(enter_room_data, 1, #data.circle)
  fk.client_callback["EnterRoom"](self, enter_room_data)

  loadRoomSummary(self, data)
end

fk.client_callback["Observe"] = function(self, data)
  local players = data.players

  if not self.replaying then
    self:startRecording()
    self.record[5] = "reconnect"
    table.insert(self.record, {math.floor(os.getms() / 1000), false, "Observe", cbor.encode(data)})
  end

  local setup_data = players[tostring(data.you)].setup_data
  self:setup(setup_data[1], setup_data[2], setup_data[3])

  local enter_room_data = { data.timeout, data.settings }
  table.insert(enter_room_data, 1, #data.circle)
  fk.client_callback["EnterRoom"](self, enter_room_data)

  loadRoomSummary(self, data)
end

fk.client_callback["PrepareDrawPile"] = function(self, data)
  local seed = tonumber(data)
  self:prepareDrawPile(seed)
end

fk.client_callback["ShuffleDrawPile"] = function(self, data)
  local seed = tonumber(data)
  self:shuffleDrawPile(seed)
end

fk.client_callback["SyncDrawPile"] = function(self, data)
  self.draw_pile = data
end

-- Create ClientInstance (used by Lua)
-- Let Cpp call this function to create
function CreateLuaClient(cpp_client)
  ClientInstance = Client:new(cpp_client)
end
dofile "lua/client/client_util.lua"

if FileIO.pwd():endsWith("packages/freekill-core") then
  FileIO.cd("../..")
end
