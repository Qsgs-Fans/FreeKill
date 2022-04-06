local Server = class("Server")

freekill.server_callback = {}

function Server:initialize()
    self.server = freekill.ServerInstance
    self.server.callback = function(_self, command, jsonData)
        local cb = freekill.server_callback[command]
        if (type(cb) == "function") then
            cb(jsonData)
        else
            print("Server error: Unknown command " .. command);
        end
    end

    self.rooms = {}     -- hashtable: uid --> room
    self.players = {}   -- hashtable: uid --> splayer
end

function Server:createRoom(owner, roomName, capacity)

end

freekill.server_callback["CreateRoom"] = function(jsonData)
    -- jsonData: [ int uid, string name, int capacity ]
    local data = json.decode(jsonData)
    local owner = freekill.ServerInstance:findPlayer(tonumber(data[1]))
    local roomName = data[2]
    local capacity = data[3]
    freekill.ServerInstance:createRoom(owner, roomName, capacity)
    ServerInstance:createRoom()
end

freekill.server_callback["EnterRoom"] = function(jsonData)
    -- jsonData: [ int uid, int roomId ]
    local data = json.decode(jsonData)
    local player = freekill.ServerInstance:findPlayer(tonumber(data[1]))
    local room = freekill.ServerInstance:findRoom(tonumber(data[2]))
    room:addPlayer(player)
end

freekill.server_callback["QuitRoom"] = function(jsonData)
    -- jsonData: [ int uid ]
    local data = json.decode(jsonData)
    local player = freekill.ServerInstance:findPlayer(tonumber(data[1]))
    local room = player:getRoom()
    if not room:isLobby() then
        room:removePlayer(player)
    end
end

freekill.server_callback["DoLuaScript"] = function(jsonData)
    -- jsonData: [ int uid, string luaScript ]
    -- warning: only use this in debugging mode.
    if not DebugMode then return end
    local data = json.decode(jsonData)
    assert(load(data[2]))()
end

ServerInstance = Server:new()
