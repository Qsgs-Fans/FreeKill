local ClientPlayer = Player:subclass("ClientPlayer")

function ClientPlayer:initialize(cp)
    self.player = cp
end

return ClientPlayer
