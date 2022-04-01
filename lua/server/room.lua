---@class Room : Object
---@field room fk.Room
---@field players ServerPlayer[]
---@field alive_players ServerPlayer[]
---@field game_finished boolean
---@field timeout integer
local Room = class("Room")

-- load classes used by the game
GameLogic = require "server.gamelogic"
ServerPlayer = require "server.serverplayer"
dofile "lua/server/event.lua"

fk.room_callback = {}

---@param _room fk.Room
function Room:initialize(_room)
    self.room = _room
    self.room.callback = function(_self, command, jsonData)
        local cb = fk.room_callback[command]
        if (type(cb) == "function") then
            cb(jsonData)
        else
            print("Lobby error: Unknown command " .. command);
        end
    end

    self.room.startGame = function(_self)
        self:run()
    end

    self.players = {}
    self.alive_players = {}
    self.game_finished = false
    self.timeout = _room:getTimeout()
end

-- When this function returns, the Room(C++) thread stopped.
function Room:run()
    for _, p in fk.qlist(self.room:getPlayers()) do
        local player = ServerPlayer:new(p)
        player.state = p:getStateString()
        player.room = self
        table.insert(self.players, player)
    end

    self.logic = GameLogic:new(self)
    self.logic:run()
end

---@param player ServerPlayer
---@param property string
function Room:broadcastProperty(player, property)
    for _, p in ipairs(self.players) do
        self:notifyProperty(p, player, property)
    end
end

---@param p ServerPlayer
---@param player ServerPlayer
---@param property string
function Room:notifyProperty(p, player, property)
    p:doNotify("PropertyUpdate", json.encode{
        player:getId(),
        property,
        player[property],
    })
end

---@param command string
---@param jsonData string
---@param players ServerPlayer[] # default all players
function Room:doBroadcastNotify(command, jsonData, players)
    players = players or self.players
    local tolist = fk.SPlayerList()
    for _, p in ipairs(players) do
        tolist:append(p.serverplayer)
    end
    self.room:doBroadcastNotify(tolist, command, jsonData)
end

---@param player ServerPlayer
---@param command string
---@param jsonData string
---@param wait boolean # default true
---@return string | nil
function Room:doRequest(player, command, jsonData, wait)
    if wait == nil then wait = true end
    player:doRequest(command, jsonData, self.timeout)

    if wait then
        return player:waitForReply(self.timeout)
    end
end

---@param command string
---@param players ServerPlayer[]
function Room:doBroadcastRequest(command, players)
    players = players or self.players
    self:notifyMoveFocus(players, command)
    for _, p in ipairs(players) do
        self:doRequest(p, command, p.request_data, false)
    end

    local remainTime = self.timeout
    local currentTime = os.time()
    local elapsed = 0
    for _, p in ipairs(players) do
        elapsed = os.time() - currentTime
        remainTime = remainTime - elapsed
        p:waitForReply(remainTime)
    end
end

---@param players ServerPlayer | ServerPlayer[]
---@param command string
function Room:notifyMoveFocus(players, command)
    if (players.class) then
        players = {players}
    end

    local ids = {}
    for _, p in ipairs(players) do
        table.insert(ids, p:getId())
    end

    self:doBroadcastNotify("MoveFocus", json.encode{
        ids,
        command
    })
end

function Room:adjustSeats()
    local players = {}
    local p = 0

    for i = 1, #self.players do
        if self.players[i].role == "lord" then
            p = i
            break
        end
    end
    for j = p, #self.players do
        table.insert(players, self.players[j])
    end
    for j = 1, p - 1 do
        table.insert(players, self.players[j])
    end

    self.players = players

    local player_circle = {}
    for i = 1, #self.players do
        self.players[i].seat = i
        table.insert(player_circle, self.players[i]:getId())
    end

    self:doBroadcastNotify("ArrangeSeats", json.encode(player_circle))
end

---@return ServerPlayer | nil
function Room:getLord()
    local lord = self.players[1]
    if lord.role == "lord" then return lord end
    for _, p in ipairs(self.players) do
        if p.role == "lord" then return p end
    end

    return nil
end

---@param expect ServerPlayer
---@return ServerPlayer[]
function Room:getOtherPlayers(expect)
    local ret = {table.unpack(self.players)}
    table.removeOne(ret, expect)
    return ret
end

---@param player ServerPlayer
---@param generals string[]
---@return string
function Room:askForGeneral(player, generals)
    local command = "AskForGeneral"
    self:notifyMoveFocus(player, command)

    if #generals == 1 then return generals[1] end
    local defaultChoice = generals[1]

    if (player.state == "online") then
        local result = self:doRequest(player, command, json.encode(generals))
        if result == "" then
            return defaultChoice
        else
            -- TODO: result is a JSON array
            -- update here when choose multiple generals
            return json.decode(result)[1]
        end
    end

    return defaultChoice
end

function Room:gameOver()
    self.game_finished = true
    -- dosomething
    self.room:gameOver()
end

---@param id integer
function Room:findPlayerById(id)
    for _, p in ipairs(self.players) do
        if p:getId() == id then
            return p
        end
    end
    return nil
end

fk.room_callback["QuitRoom"] = function(jsonData)
    -- jsonData: [ int uid ]
    local data = json.decode(jsonData)
    local player = fk.ServerInstance:findPlayer(tonumber(data[1]))
    local room = player:getRoom()
    if not room:isLobby() then
        room:removePlayer(player)
    end
end

fk.room_callback["PlayerStateChanged"] = function(jsonData)
    -- jsonData: [ int uid, string stateString ]
    -- note: this function is not called by Router.
    -- note: when this function is called, the room must be started
    local data = json.decode(jsonData)
    local id = data[1]
    local stateString = data[2]
    RoomInstance:findPlayerById(id).state = stateString
end

fk.room_callback["DoLuaScript"] = function(jsonData)
    -- jsonData: [ int uid, string luaScript ]
    -- warning: only use this in debugging mode.
    if not DebugMode then return end
    local data = json.decode(jsonData)
    assert(load(data[2]))()
end

function CreateRoom(_room)
    RoomInstance = Room:new(_room)
end
