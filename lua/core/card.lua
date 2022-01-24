-- class Card : public Object
local Card = class('Card')

-- public:

-- enum Suit
Card.Suit = {
    Spade = 0,
    Club = 1,
    Heart = 2,
    Diamond = 3,
    NoSuitBlack = 4,
    NoSuitRed = 5,
    NoSuit = 6,
    SuitToBeDecided = -1,
}

-- enum Color
Card.Color = {
    Red = 0,
    Black = 1,
    Colorless = 2,
}

-- enum HandlingMethod
Card.HandlingMethod = {
    MethodNone = 0,
    MethodUse = 1,
    MethodResponse = 2,
    MethodDiscard = 3,
    MethodRecast = 4,
    MethodPindian = 5,
}
function Card:initialize(suit, number)

end

-- private:
local subcards = {}     -- array of cards
local target_fixed
local mute
local will_throw
local has_preact
local can_recast
local m_suit
local m_number
local id
local skill_name
local handling_method
local flags = {}

return Card
