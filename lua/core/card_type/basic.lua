---@class BasicCard : Card
local BasicCard = Card:subclass("BasicCard")

function BasicCard:initialize(name, suit, number)
  Card.initialize(self, name, suit, number)
  self.type = Card.TypeBasic
end

---@param suit Suit
---@param number integer
---@return BasicCard
function BasicCard:clone(suit, number)
  local newCard = BasicCard:new(self.name, suit, number)
  return newCard
end

return BasicCard
