local Client = class('Client')

freekill.client_callback = {}

function Client:initialize()
    self.client = freekill.ClientInstance
    self.notifyUI = function(self, command, json_data)
        freekill.Backend:emitNotifyUI(command, json_data)
    end
    self.client.callback = function(_self, command, json_data)
        local cb = freekill.client_callback[command]
        if (type(cb) == "function") then
            cb(json_data)
        else
            self:notifyUI("error_msg", "Unknown command " .. command);
        end
    end
end

freekill.client_callback["enter_lobby"] = function(json_data)
    ClientInstance:notifyUI("enter_lobby", json_data)
end

-- Create ClientInstance (used by Lua)
ClientInstance = Client:new()
