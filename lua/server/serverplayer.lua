local ServerPlayer = Player:subclass("ServerPlayer")

function ServerPlayer:initialize(_self)
    Player.initialize(self)
    self.serverplayer = _self
end

function ServerPlayer:getId()
    return self.serverplayer:getId()
end

return ServerPlayer
