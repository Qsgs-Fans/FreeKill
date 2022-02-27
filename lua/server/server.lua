local Server = class('Server')

freekill.server_callback = {}

function Server:initialize()
    self.server = freekill.ServerInstance
    self.server.callback = function(_self, command, json_data)
        local cb = freekill.server_callback[command]
        if (type(cb) == "function") then
            cb(json_data)
        else
            print("Server error: Unknown command " .. command);
        end
    end
end

freekill.server_callback["create_room"] = function(json_data)
    -- json_data: [ int id, string name, int capacity ]
    local data = json.decode(json_data)
    local owner = freekill.ServerInstance:findPlayer(data[1])
    local roomName = data[2]
    local capacity = data[3]
    freekill.ServerInstance:createRoom(owner, roomName, capacity)
end

ServerInstance = Server:new()
