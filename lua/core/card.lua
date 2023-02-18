---@class Card : Object
---@field package Package
---@field name string
---@field suit Suit
---@field number integer
---@field trueName string
---@field color Color
---@field id integer
---@field type CardType
---@field sub_type CardSubtype
---@field area CardArea
---@field subcards integer[]
---@field skillName string @ for virtual cards
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

Card.TypeBasic = 1
Card.TypeTrick = 2
Card.TypeEquip = 3

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
  self.trueName = name

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
  self.skill = nil
  self.subcards = {}
  self.skillName = ""
end

---@param suit Suit
---@param number integer
---@return Card
function Card:clone(suit, number)
  local newCard = self.class:new(self.name, suit, number)
  newCard.skill = self.skill
  newCard.equip_skill = self.equip_skill
  return newCard
end

function Card:isVirtual()
  return self.id <= 0
end

function Card:getEffectiveId()
  if self:isVirtual() then
    return #self.subcards > 0 and self.subcards[1] or nil
  end
  return self.id
end

local function updateColorAndNumber(card)
  local color = Card.NoColor
  local number = 0
  local different_color = false
  for _, id in ipairs(card.subcards) do
    local c = Fk:getCardById(id)
    number = math.min(number + c.number, 13)
    if color ~= c.color then
      if not different_color then
        if color ~= Card.NoColor then
          different_color = true
        end
        color = c.color
      else
        color = Card.NoColor
      end
    end
  end

  card.color = color
  card.number = number
end

---@param card integer|Card
function Card:addSubcard(card)
  if type(card) == "number" then
    table.insert(self.subcards, card)
  else
    assert(card:isInstanceOf(Card))
    assert(not card:isVirtual(), "Can not add virtual card as subcard")
    table.insert(self.subcards, card.id)
  end

  updateColorAndNumber(self)
end

function Card:addSubcards(cards)
  for _, c in ipairs(cards) do
    self:addSubcard(c)
  end
end

function Card:clearSubcards()
  self.subcards = {}
  updateColorAndNumber(self)
end

function Card:matchPattern(pattern)
  return Exppattern:Parse(pattern):match(self)
end

function Card:getSuitString()
  local suit = self.suit
  if suit == Card.Spade then
    return "spade"
  elseif suit == Card.Heart then
    return "heart"
  elseif suit == Card.Club then
    return "club"
  elseif suit == Card.Diamond then
    return "diamond"
  else
    return "nosuit"
  end
end

function Card:getColorString()
  local color = self.color
  if color == Card.Black then
    return "black"
  elseif color == Card.Red then
    return "red"
  end
  return "nocolor"
end

function Card:getTypeString()
  local t = self.type
  if t == Card.TypeBasic then
    return "basic"
  elseif t == Card.TypeTrick then
    return "trick"
  elseif t == Card.TypeEquip then
    return "equip"
  end
  return "nocolor"
end

local function getNumberStr(num)
  if num == 1 then
    return "A"
  elseif num == 11 then
    return "J"
  elseif num == 12 then
    return "Q"
  elseif num == 13 then
    return "K"
  end
  return tostring(num)
end

-- for sendLog
function Card:toLogString()
  local ret = string.format('<font color="#0598BC"><b>%s</b></font>', Fk:translate(self.name) .. "[")
  if self:isVirtual() then
    ret = ret .. Fk:translate(self:getColorString())
  else
    ret = ret .. Fk:translate("log_" .. self:getSuitString())
    if self.number > 0 then
      ret = ret .. string.format('<font color="%s"><b>%s</b></font>', self.color == Card.Red and "#CC3131" or "black", getNumberStr(self.number))
    end
  end
  ret = ret .. '<font color="#0598BC"><b>]</b></font>'
  return ret
end

---@param c integer|integer[]|Card|Card[]
---@return integer[]
function Card.static:getIdList(c)
  if type(c) == "number" then
    return {c}
  end
  if c.class and c:isInstanceOf(Card) then
    if c:isVirtual() then
      return table.clone(c.subcards)
    else
      return {c.id}
    end
  end

  -- array
  local ret = {}
  for _, c2 in ipairs(c) do
    table.insertTable(ret, Card:getIdList(c))
  end
  return ret
end

return Card
