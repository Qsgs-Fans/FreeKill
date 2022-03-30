---@class TrickCard : Card
local TrickCard = Card:subclass("TrickCard")

function TrickCard:initialize(name, suit, number)
    Card.initialize(self, name, suit, number)
    self.type = Card.TypeTrick
end

return TrickCard
