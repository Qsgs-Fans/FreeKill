---@class Client
---@field client fk.Client
---@field players ClientPlayer[]
---@field alive_players ClientPlayer[]
---@field current ClientPlayer
---@field discard_pile integer[]
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
  self.discard_pile = {}
end

---@param id integer
---@return ClientPlayer
function Client:getPlayerById(id)
  for _, p in ipairs(self.players) do
    if p.id == id then return p end
  end
  return nil
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
        from:removeCards(move.fromArea, move.ids)
      end
    elseif move.fromArea == Card.DiscardPile then
      table.removeOne(self.discard_pile, move.ids[1])
    end

    if move.to and move.toArea then
      self:getPlayerById(move.to):addCards(move.toArea, move.ids)
    elseif move.toArea == Card.DiscardPile then
      table.insert(self.discard_pile, move.ids[1])
    end
  end
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
  ClientInstance.players = {Self}
  ClientInstance.alive_players = {Self}
  ClientInstance.discard_pile = {}
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

fk.client_callback["ArrangeSeats"] = function(jsonData)
  local data = json.decode(jsonData)
  local n = #ClientInstance.players
  local players = {}

  for i = 1, n do
    local p = ClientInstance:getPlayerById(data[i])
    p.seat = i
    table.insert(players, p)
  end
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
    local info = string.format("%q,%q,%q,%q", 
      move.from, move.to, move.fromArea, move.toArea)
    if temp[info] == nil then 
      temp[info] = {
        ids = {},
        from = move.from,
        to = move.to,
        fromArea = move.fromArea,
        toArea = move.toArea
      }
    end
    table.insert(temp[info].ids, move.ids[1])
  end
  for _, v in pairs(temp) do
    table.insert(ret, v)
  end
  return ret
end

fk.client_callback["MoveCards"] = function(jsonData)
  -- jsonData: CardsMoveStruct[]
  local raw_moves = json.decode(jsonData)
  local separated = separateMoves(raw_moves)
  ClientInstance:moveCards(separated)
  local merged = mergeMoves(separated)
  ClientInstance:notifyUI("MoveCards", json.encode(merged))
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

  -- TODO: if mark is visible, update the UI.
end

-- Create ClientInstance (used by Lua)
ClientInstance = Client:new()
dofile "lua/client/client_util.lua"
