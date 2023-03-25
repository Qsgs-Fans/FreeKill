--[[

  Exppattern is a string that describes cards of a same 'type', e.g. name,
  suit, etc.

  The string will be parsed and construct a new Exppattern instance.
  Then we can use this instance to check the card.

  Syntax for the string form:
  1. the whole string can be splited by ';'. Every slice stands for a Matcher
  2. For the matcher string, it can be splited by '|'.
  3. And the arrays in class Match is concated by ',' in string.

  Example:
  slash,jink|2~4|spade;.|.|.|.|.|trick

]]--

---@class Matcher
---@field public name string[]
---@field public number integer[]
---@field public suit string[]
---@field public place string[]
---@field public generalName string[]
---@field public cardType string[]
---@field public id integer[]

local numbertable = {
  ["A"] = 1,
  ["J"] = 11,
  ["Q"] = 12,
  ["K"] = 13,
}

local suittable = {
  [Card.Spade] = "spade",
  [Card.Club] = "club",
  [Card.Heart] = "heart",
  [Card.Diamond] = "diamond",
}

local placetable = {
  [Card.PlayerHand] = "hand",
  [Card.PlayerEquip] = "equip",
}

local typetable = {
  [Card.TypeBasic] = "basic",
  [Card.TypeTrick] = "trick",
  [Card.TypeEquip] = "equip",
}

---@param matcher Matcher
---@param card Card
local function matchCard(matcher, card)
  if type(card) == "number" then
    card = Fk:getCardById(card)
  end

  if matcher.name and not table.contains(matcher.name, card.name) and
    not table.contains(matcher.name, card.trueName) then
    return false
  end

  if matcher.number and not table.contains(matcher.number, card.number) then
    return false
  end

  if matcher.suit and not table.contains(matcher.suit, card:getSuitString()) then
    return false
  end

  if matcher.place and not table.contains(
    matcher.place,
    placetable[Fk:currentRoom():getCardArea(card.id)]
  ) then
    local piles = table.filter(matcher.place, function(e)
      return not table.contains(placetable, e)
    end)
    for _, pi in ipairs(piles) do
      if ClientInstance then
        if Self:getPileNameOfId(card.id) == pi then return true end
      else
        for _, p in ipairs(RoomInstance.alive_players) do
          local pile = p:getPileNameOfId(card.id)
          if pile == pi then return true end
        end
      end
    end
    return false
  end

  -- TODO: generalName

  if matcher.cardType and not table.contains(matcher.cardType, typetable[card.type]) then
    return false
  end

  if matcher.id and not table.contains(matcher.id, card.id) then
    return false
  end

  return true
end

local function hasIntersection(a, b)
  if a == nil or b == nil then
    return true
  end

  local tmp = {}
  for _, e in ipairs(a) do
    tmp[e] = true
  end
  for _, e in ipairs(b) do
    if tmp[e] then
      return true
    end
  end
  return false
end

---@param a Matcher
---@param b Matcher
local function matchMatcher(a, b)
  local keys = {
    "name",
    "number",
    "suit",
    "place",
    "generalName",
    "cardType",
    "id",
  }

  for _, k in ipairs(keys) do
    if not hasIntersection(a[k], b[k]) then
      return false
    end
  end

  return true
end

local function parseMatcher(str)
  local t = str:split("|")
  if #t < 7 then
    for i = 1, 7 - #t do
      table.insert(t, ".")
    end
  end

  for i, item in ipairs(t) do
    t[i] = item:split(",")
  end

  local ret = {} ---@type Matcher
  ret.name = not table.contains(t[1], ".") and t[1] or nil

  if not table.contains(t[2], ".") then
    ret.number = {}
    for _, num in ipairs(t[2]) do
      local n = tonumber(num)
      if not n then
        n = numbertable[num]
      end
      if n then
        table.insertIfNeed(ret.number, n)
      else
        if string.find(num, "~") then
          local s, e = table.unpack(num:split("~"))
          local start = tonumber(s)
          if not start then
            start = numbertable[s]
          end
          local _end = tonumber(e)
          if not _end then
            _end = numbertable[e]
          end

          for i = start, _end do
            table.insertIfNeed(ret.number, i)
          end
        end
      end
    end
  end

  ret.suit = not table.contains(t[3], ".") and t[3] or nil
  ret.place = not table.contains(t[4], ".") and t[4] or nil
  ret.generalName = not table.contains(t[5], ".") and t[5] or nil
  ret.cardType = not table.contains(t[6], ".") and t[6] or nil

  if not table.contains(t[7], ".") then
    ret.id = {}
    for _, num in ipairs(t[6]) do
      local n = tonumber(num)
      if n and n > 0 then
        table.insertIfNeed(ret.id, n)
      end
    end
  end

  return ret
end

---@class Exppattern: Object
---@field public matchers Matcher[]
local Exppattern = class("Exppattern")

function Exppattern:initialize(spec)
  if not spec then
    self.matchers = {}
  elseif spec[1] ~= nil then
    self.matchers = spec
  else
    self.matchers = {}
    self.matchers[1] = spec
  end
end

function Exppattern.static:Parse(str)
  local ret = Exppattern:new()
  local t = str:split(";")
  for i, s in ipairs(t) do
    ret.matchers[i] = parseMatcher(s)
  end
  return ret
end

---@param card Card
function Exppattern:match(card)
  for _, matcher in ipairs(self.matchers) do
    local result = matchCard(matcher, card)
    if result then
      return true
    end
  end
  return false
end

function Exppattern:matchExp(exp)
  if type(exp) == "string" then
    exp = Exppattern:Parse(exp)
  end

  local a = self.matchers
  local b = exp.matchers

  for _, m in ipairs(a) do
    for _, n in ipairs(b) do
      if matchMatcher(m, n) then
        return true
      end
    end
  end

  return false
end

return Exppattern
