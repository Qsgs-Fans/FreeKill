---@class Client
---@field client fk.Client
---@field players ClientPlayer[]
---@field alive_players ClientPlayer[]
---@field current ClientPlayer
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
end

---@param id integer
---@return ClientPlayer
function Client:getPlayerById(id)
  for _, p in ipairs(self.players) do
    if p.player:getId() == id then return p end
  end
  return nil
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
  fk.ClientInstance:removePlayer(id)
  ClientInstance:notifyUI("RemovePlayer", jsonData)
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

--- merge separated moves (one fromArea per move)
local function mergeMoves(moves)
  local ret = {}
  local temp = {}
  for _, move in ipairs(moves) do
    if temp[move.fromArea] == nil then 
      temp[move.fromArea] = {
        ids = {},
        from = move.from,
        to = move.to,
        fromArea = move.fromArea,
        toArea = move.toArea
      }
    end
    table.insert(temp[move.fromArea].ids, move.ids[1])
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
  local merged = mergeMoves(separated)
  ClientInstance:notifyUI("MoveCards", json.encode(merged))
end

-- Create ClientInstance (used by Lua)
ClientInstance = Client:new()
dofile "lua/client/client_util.lua"
