---@class Card : Object
---@field package Package
---@field name string
---@field suit Suit
---@field number integer
---@field color Color
---@field id integer
---@field type CardType
---@field sub_type CardSubtype
---@field area CardArea
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

---@alias CardSubtype integer

Card.SubtypeNone = 1
Card.SubtypeDelayedTrick = 2
Card.SubtypeWeapon = 3
Card.SubtypeArmor = 4
Card.SubtypeDefensiveRide = 5
Card.SubtypeOffensiveRide = 6
Card.SubtypeTreasure = 7

---@alias CardArea integer

Card.Unknown = 0
Card.PlayerHand = 1
Card.PlayerEquip = 2
Card.PlayerJudge = 3
Card.PlayerSpecial = 4
Card.Processing = 5
Card.DrawPile = 6
Card.DiscardPile = 7
Card.Void = 8

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
    self.sub_type = Card.SubTypeNone
end

return Card
