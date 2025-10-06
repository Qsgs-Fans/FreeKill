-- SPDX-License-Identifier: GPL-3.0-or-later

---@class TrickCard : Card
local TrickCard = Card:subclass("TrickCard")

function TrickCard:initialize(name, suit, number)
  Card.initialize(self, name, suit, number)
  self.type = Card.TypeTrick
end

---@class DelayedTrickCard : TrickCard
local DelayedTrickCard = TrickCard:subclass("DelayedTrickCard")

function DelayedTrickCard:initialize(name, suit, number)
  TrickCard.initialize(self, name, suit, number)
  self.sub_type = Card.SubtypeDelayedTrick
end

return { TrickCard, DelayedTrickCard }
