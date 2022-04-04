---@class TrickCard : Card
local TrickCard = Card:subclass("TrickCard")

function TrickCard:initialize(name, suit, number)
    Card.initialize(self, name, suit, number)
    self.type = Card.TypeTrick
end

---@param suit Suit
---@param number integer
---@return TrickCard
function TrickCard:clone(suit, number)
    local newCard = TrickCard:new(self.name, suit, number)
    return newCard
end

---@class DelayedTrickCard : TrickCard
local DelayedTrickCard = TrickCard:subclass("DelayedTrickCard")

function DelayedTrickCard:initialize(name, suit, number)
    TrickCard.initialize(self, name, suit, number)
    self.sub_type = Card.SubtypeDelayedTrick
end

---@param suit Suit
---@param number integer
---@return DelayedTrickCard
function DelayedTrickCard:clone(suit, number)
    local newCard = DelayedTrickCard:new(self.name, suit, number)
    return newCard
end

return { TrickCard, DelayedTrickCard }
