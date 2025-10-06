-- SPDX-License-Identifier: GPL-3.0-or-later

---@class BasicCard : Card
local BasicCard = Card:subclass("BasicCard")

function BasicCard:initialize(name, suit, number)
  Card.initialize(self, name, suit, number)
  self.type = Card.TypeBasic
end

return BasicCard
