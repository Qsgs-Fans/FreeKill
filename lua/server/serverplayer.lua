local ServerPlayer = Player:subclass("ServerPlayer")

function ServerPlayer:initialize(_self)
    Player.initialize(self)
    self.serverplayer = _self

    self.next = nil

    -- Below are for doBroadcastRequest
    self.request_data = ""
    self.client_reply = ""
    self.reply_ready = false
end

function ServerPlayer:getId()
    return self.serverplayer:getId()
end

function ServerPlayer:doNotify(command, jsonData)
    self.serverplayer:doNotify(command, jsonData)
end

function ServerPlayer:doRequest(command, jsonData, timeout)
    timeout = timeout or self.room.timeout
    self.client_reply = ""
    self.reply_ready = false
    self.serverplayer:doRequest(command, jsonData, timeout)
end

function ServerPlayer:waitForReply(timeout)
    local result = ""
    if timeout == nil then
        result = self.serverplayer:waitForReply()
    else
        result = self.serverplayer:waitForReply(timeout)
    end
    self.request_data = ""
    self.client_reply = result
    if result ~= "" then self.reply_ready = true end
    return result
end

return ServerPlayer
