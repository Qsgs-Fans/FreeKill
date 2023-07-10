-- SPDX-License-Identifier: GPL-3.0-or-later

--[[

  Exppattern 是一个用来描述卡牌的字符串。
  pattern 字符串会被用来构建新的 Exppattern 对象，然后可以用它来检查一张牌。

  pattern 字符串的语法：
  1. 整个字符串可以被分号 (';') 切割，每一个分割就是一个 Matcher
  2. 对于 Matcher 字符串，它是用 ('|') 分割的
  3. 然后在 Matcher 的每一个细分中，又可以用 ',' 来进行更进一步的分割

  其中 Matcher 的格式为 牌名|花色|点数|位置|详细牌名|类型|牌的id
  更进一步，“点数” 可以用 '~' 符号表示数字的范围，并且可以用 AJQK 表示对应点数

  例如：
  slash,jink|2~4|spade;.|.|.|.|.|trick

  你可以使用 '^' 符号表示否定，比如 ^heart 表示除了红桃之外的所有花色。
  否定型一样的可以与其他表达式并用，用 ',' 分割。
  如果要同时否定多项，则需要用括号： ^(heart, club) 等。
  注：这种括号不支持嵌套否定。

]]--

---@class Matcher
---@field public trueName string[]
---@field public number integer[]
---@field public suit string[]
---@field public place string[]
---@field public name string[]
---@field public cardType string[]
---@field public id integer[]

-- v0.2.6改动： cardType会被解析为trueName数组和name数组，而不是自己单独成立

local numbertable = {
  ["A"] = 1,
  ["J"] = 11,
  ["Q"] = 12,
  ["K"] = 13,
}

local placetable = {
  [Card.PlayerHand] = "hand",
  [Card.PlayerEquip] = "equip",
}

local card_type_table = {}

local function fillCardTypeTable()
  local tmp = {}
  for _, cd in ipairs(Fk.cards) do
    local t = cd:getTypeString()
    local st = cd:getSubtypeString()
    local tn = cd.trueName
    -- TODO: local n = cd.name

    if not tmp[tn] then
      card_type_table[t] = card_type_table[t] or {}
      card_type_table[st] = card_type_table[st] or {}
      table.insertIfNeed(card_type_table[t], tn)
      table.insertIfNeed(card_type_table[st], tn)
      tmp[tn] = true
    end
  end
end

local function matchSingleKey(matcher, card, key)
  local match = matcher[key]
  if not match then return true end
  local val = card[key]
  if key == "suit" then
    val = card:getSuitString()
  -- elseif key == "cardType" then
  --   val = card:getTypeString()
  elseif key == "place" then
    val = placetable[Fk:currentRoom():getCardArea(card.id)]
    if not val then
      for _, p in ipairs(Fk:currentRoom().alive_players) do
        val = p:getPileNameOfId(card.id)
        if val then break end
      end
    end
  end

  if table.contains(match, val) then
    return true
  else
    local neg = match.neg
    if not neg then return false end
    for _, t in ipairs(neg) do
      if type(t) == "table" then
        if not table.contains(t, val) then return true end
      else
        if t ~= val then return true end
      end
    end
  end
  return false
end

---@param matcher Matcher
---@param card Card
local function matchCard(matcher, card)
  if type(card) == "number" then
    card = Fk:getCardById(card)
  end

  return matchSingleKey(matcher, card, "trueName")
     and matchSingleKey(matcher, card, "number")
     and matchSingleKey(matcher, card, "suit")
     and matchSingleKey(matcher, card, "place")
     and matchSingleKey(matcher, card, "name")
     -- and matchSingleKey(matcher, card, "cardType")
     and matchSingleKey(matcher, card, "id")
end

local function hasNegIntersection(a, b)
  -- 注意，这里是拿a.neg和b比
  local neg_pass = false

  -- 第一次比较： 比较neg和正常值，如有不同即认为可以匹配
  -- 比如 ^jink 可以匹配 slash,jink
  for _, neg in ipairs(a.neg or Util.DummyTable) do
    for _, e in ipairs(b) do
      if type(neg) == "table" then
        neg_pass = not table.contains(neg, e)
      else
        neg_pass = neg ~= e
      end
      if neg_pass then return true end
    end
  end

  -- 第二次比较： 比较双方neg
  -- 比如 ^jink 可以匹配 ^slash
  -- 没法比
end

local function hasIntersection(a, b)
  if a == nil or b == nil or (#a + #b == 0) then
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
  local neg_pass = hasNegIntersection(a, b) or hasNegIntersection(b, a)

  return neg_pass
end

---@param a Matcher
---@param b Matcher
local function matchMatcher(a, b)
  local keys = {
    "trueName",
    "number",
    "suit",
    "place",
    "name",
    -- "cardType",
    "id",
  }

  for _, k in ipairs(keys) do
    if not hasIntersection(a[k], b[k]) then
      return false
    end
  end

  return true
end

local function parseNegative(list)
  local bracket = nil
  local toRemove = {}
  for i, element in ipairs(list) do
    if element[1] == "^" or bracket then
      list.neg = list.neg or {}
      table.insert(toRemove, 1, i)
      if element[1] == "^" and element[2] == "(" then
        if bracket then
          error("pattern syntax error. Cannot use nested bracket.")
        else
          bracket = {}
        end
        element = element:sub(3)
      else
        if element[1] == "^" then
          element = element:sub(2)
        end
      end

      local eofBracket
      if element:endsWith(")") then
        eofBracket = true
        element = element:sub(1, -2)
      end

      if eofBracket then
        if not bracket then
          error('pattern syntax error. No matching bracket.')
        else
          table.insert(bracket, element)
          table.insert(list.neg, bracket)
          bracket = nil
        end
      else
        if bracket then
          table.insert(bracket, element)
        else
          table.insert(list.neg, element)
        end
      end
    end
  end

  for _, i in ipairs(toRemove) do
    table.remove(list, i)
  end
end

local function parseNumToTable(from, dest)
  for _, num in ipairs(from) do
    if type(num) ~= "string" then goto continue end
    local n = tonumber(num)
    if not n then
      n = numbertable[num]
    end
    if n then
      table.insertIfNeed(dest, n)
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
          table.insertIfNeed(dest, i)
        end
      end
    end
    ::continue::
  end
end

local function parseRawNumTable(tab)
  local ret = {}
  parseNumToTable(tab, ret)

  if tab.neg then
    ret.neg = {}
    parseNumToTable(tab.neg, ret.neg)

    for _, t in ipairs(tab.neg) do
      if type(t) == "table" then
        local tmp = {}
        parseNumToTable(t, tmp)
        table.insert(ret.neg, tmp)
      end
    end
  end
  return ret
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

  for _, list in ipairs(t) do
    parseNegative(list)
  end

  local ret = {} ---@type Matcher
  ret.trueName = not table.contains(t[1], ".") and t[1] or nil

  if not table.contains(t[2], ".") then
    ret.number = parseRawNumTable(t[2])
  end

  ret.suit = not table.contains(t[3], ".") and t[3] or nil
  ret.place = not table.contains(t[4], ".") and t[4] or nil
  ret.name = not table.contains(t[5], ".") and t[5] or nil
  -- ret.cardType = not table.contains(t[6], ".") and t[6] or nil
  if table.empty(card_type_table) then
    fillCardTypeTable()
  end
  for _, ctype in ipairs(t[6]) do
    for _, n in ipairs(card_type_table[ctype] or Util.DummyTable) do
      if not ret.trueName then ret.trueName = {} end
      table.insertIfNeed(ret.trueName, n)
    end
  end
  for _, neg in ipairs(t[6].neg or Util.DummyTable) do
    if type(neg) ~= "table" then neg = { neg } end
    if not ret.trueName then ret.trueName = {} end
    if not ret.trueName.neg then ret.trueName.neg = {} end

    local temp = {}
    for _, ctype in ipairs(neg) do
      table.insertTable(temp, card_type_table[ctype] or Util.DummyTable)
    end
    table.insert(ret.trueName.neg, temp)
  end

  if not table.contains(t[7], ".") then
    ret.id = parseRawNumTable(t[7])
  end

  return ret
end

local function matcherKeyToString(tab)
  if not tab then return "." end
  local ret = table.concat(tab, ",")
  if tab.neg then
    for _, t in ipairs(tab.neg) do
      if ret ~= "" then ret = ret .. "," end
      if type(t) == "table" then
        ret = ret .. ("^(" .. table.concat(t, ",") .. ")")
      else
        ret = ret .. "^" .. t
      end
    end
  end
  return ret
end

local function matcherToString(matcher)
  return table.concat({
    matcherKeyToString(matcher.trueName),
    matcherKeyToString(matcher.number),
    matcherKeyToString(matcher.suit),
    matcherKeyToString(matcher.place),
    matcherKeyToString(matcher.name),
    matcherKeyToString(matcher.cardType),
    matcherKeyToString(matcher.id),
  }, "|")
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

---@param pattern string
---@return Exppattern
function Exppattern:Parse(pattern)
  error("This is a static method. Please use Exppattern:Parse instead")
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

function Exppattern:__tostring()
  local ret = ""
  for i, matcher in ipairs(self.matchers) do
    if i > 1 then ret = ret .. ";" end
    ret = ret .. matcherToString(matcher)
  end
  return ret
end

return Exppattern
