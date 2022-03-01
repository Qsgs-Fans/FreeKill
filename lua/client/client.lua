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
            self:notifyUI(command, json_data);
        end
    end
end

-- Create ClientInstance (used by Lua)
ClientInstance = Client:new()
