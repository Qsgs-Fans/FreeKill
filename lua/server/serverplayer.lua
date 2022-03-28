local ServerPlayer = Player:subclass("ServerPlayer")

function ServerPlayer:initialize(_self)
    Player.initialize(self)
    self.serverplayer = _self
end

function ServerPlayer:getId()
    return self.serverplayer:getId()
end

function ServerPlayer:setRole(role)
    self.role = role
end

function ServerPlayer:doNotify(command, jsonData)
    self.serverplayer:doNotify(command, jsonData)
end

function ServerPlayer:doRequest(command, jsonData, timeout)
    self.serverplayer:doRequest(command, jsonData, timeout)
end

return ServerPlayer
