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

ServerInstance = Server:new()
