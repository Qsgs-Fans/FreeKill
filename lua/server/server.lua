---@class Server : Object
---@field server fk.Server
---@field db fk.SQLite3
---@field rooms table
---@field players table
Server = class('Server')

-- load server classes
Room = require "server.room"
GameLogic = require "server.gamelogic"
ServerPlayer = require "server.serverplayer"

fk.server_callback = {}

function Server:initialize()
    self.server = fk.ServerInstance
    self.db = fk.ServerInstance:getDatabase()
    self.server.callback = function(_self, command, jsonData)
        local cb = fk.server_callback[command]
        if (type(cb) == "function") then
            cb(jsonData)
        else
            print("Server error: Unknown command " .. command);
        end
    end

    self.server.startRoom = function(_self, _room)
        local room = Room:new(_room)
        room.server = self
        table.insert(self.rooms, room)

        room:run()

        -- If room.run returns, the game is over and lua room
        -- should be destoried now.
        -- This behavior does not affect C++ Room.
        table.removeOne(self.rooms, room)
    end

    self.rooms = {}     -- id --> Room(Started)
    self.players = {}   -- id --> ServerPlayer
end

fk.server_callback["UpdateAvatar"] = function(jsonData)
    -- jsonData: [ int uid, string newavatar ]
    local data = json.decode(jsonData)
    local id, avatar = data[1], data[2]
    local sql = "UPDATE userinfo SET avatar='%s' WHERE id=%d;"
    Sql.exec(ServerInstance.db, string.format(sql, avatar, id))
    local player = fk.ServerInstance:findPlayer(id)
    player:setAvatar(avatar)
    player:doNotify("UpdateAvatar", avatar)
end

fk.server_callback["UpdatePassword"] = function(jsonData)
    -- jsonData: [ int uid, string oldpassword, int newpassword ]
    local data = json.decode(jsonData)
    local id, old, new = data[1], data[2], data[3]
    local sql_find = "SELECT password FROM userinfo WHERE id=%d;"
    local sql_update = "UPDATE userinfo SET password='%s' WHERE id=%d;"

    local db = ServerInstance.db
    local passed = false
    local result = Sql.exec_select(db, string.format(sql_find, id))
    passed = (result["password"][1] == sha256(old))
    if passed then
        Sql.exec(db, string.format(sql_update, sha256(new), id))
    end

    local player = fk.ServerInstance:findPlayer(tonumber(id))
    player:doNotify("UpdatePassword", passed and "1" or "0")
end

fk.server_callback["CreateRoom"] = function(jsonData)
    -- jsonData: [ int uid, string name, int capacity ]
    local data = json.decode(jsonData)
    local owner = fk.ServerInstance:findPlayer(tonumber(data[1]))
    local roomName = data[2]
    local capacity = data[3]
    fk.ServerInstance:createRoom(owner, roomName, capacity)
end

fk.server_callback["EnterRoom"] = function(jsonData)
    -- jsonData: [ int uid, int roomId ]
    local data = json.decode(jsonData)
    local player = fk.ServerInstance:findPlayer(tonumber(data[1]))
    local room = fk.ServerInstance:findRoom(tonumber(data[2]))
    room:addPlayer(player)
end

fk.server_callback["QuitRoom"] = function(jsonData)
    -- jsonData: [ int uid ]
    local data = json.decode(jsonData)
    local player = fk.ServerInstance:findPlayer(tonumber(data[1]))
    local room = player:getRoom()
    if not room:isLobby() then
        room:removePlayer(player)
    end
end

fk.server_callback["DoLuaScript"] = function(jsonData)
    -- jsonData: [ int uid, string luaScript ]
    -- warning: only use this in debugging mode.
    if not DebugMode then return end
    local data = json.decode(jsonData)
    assert(load(data[2]))()
end

fk.server_callback["PlayerStateChanged"] = function(jsonData)
    -- jsonData: [ int uid, string stateString ]
    -- note: this function is not called by Router.
    local data = json.decode(jsonData)
    local id = data[1]
    local stateString = data[2]
    ServerInstance.players[id].state = stateString
end

ServerInstance = Server:new()
