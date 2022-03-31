---@class EquipCard : Card
local EquipCard = Card:subclass("EquipCard")

function EquipCard:initialize(name, suit, number)
    Card.initialize(self, name, suit, number)
    self.type = Card.TypeEquip
end

return EquipCard
