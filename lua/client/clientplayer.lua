-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ClientPlayer: Player
---@field public player fk.Player
---@field public known_cards integer[]
---@field public global_known_cards integer[]
local ClientPlayer = Player:subclass("ClientPlayer")

function ClientPlayer:initialize(cp)
  Player.initialize(self)
  self.id = cp:getId()
  self.player = cp
  self.known_cards = {}   -- you know he/she have this card, but not shown
  self.global_known_cards = {}  -- card that visible to all players
end

return ClientPlayer
