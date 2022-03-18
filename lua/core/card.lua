local SUITS = {
  "Spade",
  "Club",
  "Diamond",
  "Heart",
  "NonSuit",
}

CardSuit = Util:createEnum(SUITS)

local COLOR = {
  "Red",
  "Black",
  "NonColor",
}

CardColor = Util:createEnum(COLOR)

local Card = class("Card")

function Card:initialize(name, suit, cardNumber)
  self.name = name
  self.suit = suit
  self.cardNumber = cardNumber
end

function Card:getColor()
  if self.suit == CardSuit.Spade or self.suit == CardSuit.Club then
    return CardColor.Red
  elseif self.suit == CardSuit.Diamond or self.suit == CardSuit.Heart then
    return CardColor.Black
  else
    return CardColor.NonColor
  end
end

return Card
