---@class Card : Object
---@field package Package
---@field name string
---@field suit number # enum suit
---@field number number
---@field color number # enum color
---@field id number
---@field type number # enum type
local Card = class("Card")

-- enum Suit
freekill.createEnum(Card, {
    "Spade",
    "Club",
    "Heart",
    "Diamond",
    "NoSuit"
})

-- enum Color
freekill.createEnum(Card, {
    "Black",
    "Red",
    "NoColor"
})

-- enum Type
freekill.createEnum(Card, {
    "TypeSkill",
    "TypeBasic",
    "TypeTrick",
    "TypeEquip"
})

function Card:initialize(name, suit, number, color)
    self.name = name
    self.suit = suit or Card.NoSuit
    self.number = number or 0

    if suit == Card.Spade or suit == Card.Club then
        self.color = Card.Black
    elseif suit == Card.Heart or suit == Card.Diamond then
        self.color = Card.Red
    elseif color ~= nil then
        self.color = color
    else
        self.color = Card.NoColor
    end

    self.package = nil
    self.id = 0
    self.type = 0
end

return Card
