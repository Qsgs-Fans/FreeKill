---@class ClientPlayer: Player
---@field player fk.Player
---@field handcardNum integer
---@field known_cards integer[]
local ClientPlayer = Player:subclass("ClientPlayer")

function ClientPlayer:initialize(cp)
  self.player = cp
  self.handcardNum = 0
  self.known_cards = {}
end

return ClientPlayer
