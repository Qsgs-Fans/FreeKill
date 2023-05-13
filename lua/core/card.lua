-- SPDX-License-Identifier: GPL-3.0-or-later

--- Card记录了FreeKill所有卡牌的基础信息。
---
--- 它包含了ID、所属包、牌名、花色、点数等等
---
---@class Card : Object
---@field public id integer @ 标志某一张卡牌唯一的数字，从1开始。若此牌是虚拟牌，则其id为0。服务器启动时为卡牌赋予ID。
---@field public package Package @ 卡牌所属的扩展包
---@field public name string @ 卡牌的名字
---@field public suit Suit @ 卡牌的花色（四色及无花色）
---@field public number integer @ 卡牌的点数（0到K）
---@field public trueName string @ 卡牌的真名，一般用于分辨杀。
---@field public color Color @ 卡牌的颜色（分为黑色、红色、无色）
---@field public type CardType @ 卡牌的种类（基本牌、锦囊牌、装备牌）
---@field public sub_type CardSubtype @ 卡牌的子种类（例如延时锦囊牌、武器、防具等）
---@field public area CardArea @ 卡牌所在区域（例如手牌区，判定区，装备区，牌堆，弃牌堆···）
---@field public mark table<string, integer> @ 当前拥有的所有标记，用烂了
---@field public subcards integer[]
---@field public skillName string @ for virtual cards
---@field public skillNames string[]
---@field public skill Skill
---@field public special_skills string[] | nil
---@field public is_damage_card boolean
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

--- Card的构造函数。具体负责构建Card实例的函数，请参见fk_ex部分。
function Card:initialize(name, suit, number, color)
  self.name = name
  self.suit = suit or Card.NoSuit
  self.number = number or 0

  local name_splited = name:split("__")
  self.trueName = name_splited[#name_splited]

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
  self.skillName = nil -- ""
  self._skillName = ""
  self.skillNames = {}
  self.mark = {}

  local mt = table.simpleClone(getmetatable(self))
  local newidx = mt.__newindex or rawset
  mt.__newindex = function(t, k, v)
    if k == "skillName" then
      table.insertIfNeed(self.skillNames, v)
      t._skillName = v
    else
      return newidx(t, k, v)
    end
  end

  local idx = mt.__index or rawget
  mt.__index = function(t, k)
    if k == "skillName" then
      return t._skillName
    end
    if type(idx) == "table" then
      return idx[k]
    end
    if type(idx) == "function" then
      return idx(t, k)
    end
  end
  setmetatable(self, mt)
end

function Card:__tostring()
  return string.format("<Card %s[%s %d]>", self.name, self:getSuitString(), self.number)
end

--- 克隆特定卡牌并赋予花色与点数。
---
--- 会将skill/special_skills/equip_skill继承到克隆牌中。
---@param suit Suit @ 克隆后的牌的花色
---@param number integer @ 克隆后的牌的点数
---@return Card @ 产品
function Card:clone(suit, number)
  local newCard = self.class:new(self.name, suit, number)
  newCard.skill = self.skill
  newCard.special_skills = self.special_skills
  newCard.equip_skill = self.equip_skill
  newCard.attack_range = self.attack_range
  newCard.is_damage_card = self.is_damage_card
  return newCard
end

--- 检测是否为虚拟卡牌，如果其ID为0及以下，则为虚拟卡牌。
function Card:isVirtual()
  return self.id <= 0
end

--- 获取卡牌的ID。
---
--- 如果牌是虚拟牌，则返回其第一张子卡的id，没有子卡就返回nil
---@return integer | nil
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
  for i, id in ipairs(card.subcards) do
    local c = Fk:getCardById(id)
    number = math.min(number + c.number, 13)
    if i == 1 then
      card.suit = c.suit
    else
      card.suit = Card.NoSuit
    end

    if color ~= c.color then
      if not different_color then
        if c.color ~= Card.NoColor then
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

--- 将一张子卡牌加入某张牌中（是addSubcards的基础函数，常用addSubcards）。
---@param card integer|Card @ 要加入的子卡
function Card:addSubcard(card)
  if type(card) == "number" then
    table.insert(self.subcards, card)
  else
    assert(card:isInstanceOf(Card))
    -- assert(not card:isVirtual(), "Can not add virtual card as subcard")
    if card:isVirtual() then
      table.insertTable(self.subcards, card.subcards)
    else
      table.insert(self.subcards, card.id)
    end

    for _, skill in ipairs(card.skillNames) do
      self.skillName = skill
    end
  end

  updateColorAndNumber(self)
end

--- 将一批子卡牌加入某张牌中（常用于将这批牌弃置/交给某个角色···）。
---@param cards integer[] | Card[] @ 要加入的子卡列表
function Card:addSubcards(cards)
  for _, c in ipairs(cards) do
    self:addSubcard(c)
  end
end

--- 清空加入某张牌中的子卡牌。
function Card:clearSubcards()
  self.subcards = {}
  updateColorAndNumber(self)
end

--- 判断此牌能否符合一个卡牌规则。
function Card:matchPattern(pattern)
  return Exppattern:Parse(pattern):match(self)
end

--- 获取卡牌花色并返回花色文字描述（如 黑桃、红桃、梅花、方块）。
---@return string @ 描述花色的字符串
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

--- 获取卡牌颜色并返回点数颜色描述（例如黑色/红色/无色）。
---@return string @ 描述颜色的字符串
function Card:getColorString()
  local color = self.color
  if color == Card.Black then
    return "black"
  elseif color == Card.Red then
    return "red"
  end
  return "nocolor"
end

--- 获取卡牌类型并返回点数类型描述（例如基本牌/锦囊牌/装备牌）。
function Card:getTypeString()
  local t = self.type
  if t == Card.TypeBasic then
    return "basic"
  elseif t == Card.TypeTrick then
    return "trick"
  elseif t == Card.TypeEquip then
    return "equip"
  end
  return "notype"
end

--- 获取卡牌点数并返回点数文字描述（仅限A/J/Q/K）。
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

--- 为卡牌赋予Mark。
---@param mark string @ 标记
---@param count integer @ 为标记赋予的数量
-- mark name and UI:
-- 'xxx': invisible mark
-- '@mark': mark with extra data (maybe string or number)
-- '@@mark': mark without data
function Card:addMark(mark, count)
  count = count or 1
  local num = self.mark[mark]
  num = num or 0
  self:setMark(mark, math.max(num + count, 0))
end

--- 为卡牌移除Mark。
---@param mark string @ 标记
---@param count integer @ 为标记删除的数量
function Card:removeMark(mark, count)
  count = count or 1
  local num = self.mark[mark]
  num = num or 0
  self:setMark(mark, math.max(num - count, 0))
end

--- 为卡牌设置Mark至指定数量。
---@param mark string @ 标记
---@param count integer @ 为标记删除的数量
function Card:setMark(mark, count)
  if self.mark[mark] ~= count then
    self.mark[mark] = count
  end
end

--- 获取卡牌对应Mark的数量。
---@param mark string @ 标记
---@param count integer @ 为标记删除的数量
function Card:getMark(mark)
  return (self.mark[mark] or 0)
end

--- 获取卡牌有哪些Mark。
function Card:getMarkNames()
  local ret = {}
  for k, _ in pairs(self.mark) do
    table.insert(ret, k)
  end
  return ret
end

-- for sendLog
--- 获取卡牌的文字信息并准备作为log发送。
function Card:toLogString()
  local ret = string.format('<font color="#0598BC"><b>%s</b></font>', Fk:translate(self.name) .. "[")
  if self:isVirtual() and #self.subcards ~= 1 then
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

--- 静态方法。传入下列类型之一的参数，返回id列表。
---@param c integer|integer[]|Card|Card[]
---@return integer[]
function Card:getIdList(c)
  error("This is a static method. Please use Card:getIdList instead")
end

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
    table.insertTable(ret, Card:getIdList(c2))
  end
  return ret
end

return Card
