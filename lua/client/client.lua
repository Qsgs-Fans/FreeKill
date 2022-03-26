local Client = class('Client')

freekill.client_callback = {}

function Client:initialize()
    self.client = freekill.ClientInstance
    self.notifyUI = function(self, command, jsonData)
        freekill.Backend:emitNotifyUI(command, jsonData)
    end
    self.client.callback = function(_self, command, jsonData)
        local cb = freekill.client_callback[command]
        if (type(cb) == "function") then
            cb(jsonData)
        else
            self:notifyUI(command, jsonData);
        end
    end
end

freekill.client_callback["Setup"] = function(jsonData)
    -- jsonData: [ int id, string screenName, string avatar ]
    local data = json.decode(jsonData)
    local id, name, avatar = data[1], data[2], data[3]
    local self = freekill.Self
    self:setId(id)
    self:setScreenName(name)
    self:setAvatar(avatar)
end

freekill.client_callback["AddPlayer"] = function(jsonData)
    -- jsonData: [ int id, string screenName, string avatar ]
    -- when other player enter the room, we create clientplayer(C and lua) for them
    local data = json.decode(jsonData)
    local id, name, avatar = data[1], data[2], data[3]
    ClientInstance:notifyUI("AddPlayer", json.encode({ name, avatar }))
end

-- Create ClientInstance (used by Lua)
ClientInstance = Client:new()
