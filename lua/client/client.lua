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

-- Create ClientInstance (used by Lua)
ClientInstance = Client:new()
