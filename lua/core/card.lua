---@class Card : Object
---@field package Package
---@field name string
---@field suit Suit
---@field number integer
---@field color Color
---@field id integer
---@field type CardType
local Card = class("Card")

---@alias Suit integer

Card.Spade = 1
Card.Club = 2
Card.Heart = 3
Card.Diamond = 4
Card.NoSuit = 5

---@alias Color integer

Card.Black = 1
Card.Red = 2
Card.NoColor = 3

---@alias CardType integer

Card.TypeSkill = 1
Card.TypeBasic = 2
Card.TypeTrick = 3
Card.TypeEquip = 4

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
