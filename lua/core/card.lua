---@class Card : Object
---@field package Package
---@field name string
---@field suit integer # enum suit
---@field number integer
---@field color integer # enum color
---@field id integer
---@field type integer # enum type
local Card = class("Card")

-- enum Suit
fk.createEnum(Card, {
    "Spade",
    "Club",
    "Heart",
    "Diamond",
    "NoSuit"
})

-- enum Color
fk.createEnum(Card, {
    "Black",
    "Red",
    "NoColor"
})

-- enum Type
fk.createEnum(Card, {
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
