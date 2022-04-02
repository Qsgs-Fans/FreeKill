Client = class('Client')

-- load client classes
ClientPlayer = require "client.clientplayer"
dofile "lua/client/client_util.lua"

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

    self.players = {}       -- ClientPlayer[]
end

fk.client_callback["Setup"] = function(jsonData)
    -- jsonData: [ int id, string screenName, string avatar ]
    local data = json.decode(jsonData)
    local id, name, avatar = data[1], data[2], data[3]
    local self = fk.Self
    self:setId(id)
    self:setScreenName(name)
    self:setAvatar(avatar)
end

fk.client_callback["AddPlayer"] = function(jsonData)
    -- jsonData: [ int id, string screenName, string avatar ]
    -- when other player enter the room, we create clientplayer(C and lua) for them
    local data = json.decode(jsonData)
    local id, name, avatar = data[1], data[2], data[3]
    local player = fk.ClientInstance:addPlayer(id, name, avatar)
    table.insert(ClientInstance.players, ClientPlayer:new(player))
    ClientInstance:notifyUI("AddPlayer", jsonData)
end

fk.client_callback["RemovePlayer"] = function(jsonData)
    -- jsonData: [ int id ]
    local data = json.decode(jsonData)
    local id = data[1]
    fk.ClientInstance:removePlayer(id)
    for _, p in ipairs(ClientInstance.players) do
        if p.player:getId() == id then
            table.removeOne(ClientInstance.players, p)
            break
        end
    end
    ClientInstance:notifyUI("RemovePlayer", jsonData)
end

fk.client_callback["ArrangeSeats"] = function(jsonData)
    local data = json.decode(jsonData)
    local n = #ClientInstance.players
    local players = {}
    local function findPlayer(id)
        for _, p in ipairs(ClientInstance.players) do
            if p.player:getId() == id then return p end
        end
        return nil
    end

    for i = 1, n do
        table.insert(players, findPlayer(data[i]))
    end
    ClientInstance.players = players

    ClientInstance:notifyUI("ArrangeSeats", jsonData)
end

-- Create ClientInstance (used by Lua)
ClientInstance = Client:new()
