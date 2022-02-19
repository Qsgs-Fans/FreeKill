Client = class('Client')

function Client:initialize()
    self.client = freekill.ClientInstance
    self.client.callback = function()
        print 'this function is called by c'
        self:notifyServer("client", "{client test}")
    end
end

function Client:notifyServer(command, json_data)
    self.client:notifyServer(command, json_data)
end
