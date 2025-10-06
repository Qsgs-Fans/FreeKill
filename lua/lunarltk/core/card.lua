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
---@field public subcards integer[] @ 子卡ID表
---@field public fake_subcards integer[] @ 伪子卡ID表，用于活墨类转化和飞刀判定
---@field public skillName string @ 虚拟牌的技能名 for virtual cards
---@field private _skillName string
---@field public skillNames string[] @ 虚拟牌的技能名们（一张虚拟牌可能有多个技能名，如芳魂、龙胆、朱雀羽扇）
---@field public skill CardSkill @ 技能（用于实现卡牌效果）
---@field public special_skills? string[] @ 衍生技能，如重铸
---@field public is_damage_card boolean @ 是否为会造成伤害的牌
---@field public multiple_targets boolean @ 是否为指定多个目标的牌
---@field public stackable_delayed boolean @ 是否为可堆叠的延时锦囊牌
---@field public is_passive? boolean @ 是否只能在响应时使用或打出
---@field public is_derived? boolean @ 判断是否为衍生牌
---@field public virt_id integer @ 虚拟牌的特殊id，默认为0
---@field public extra_data? table @ 保存其他信息的键值表，如“合纵”、“应变”、“赠予”等
local Card = class("Card")

---@alias Suit integer

--- 黑桃
Card.Spade = 1
--- 梅花
Card.Club = 2
--- 红桃
Card.Heart = 3
--- 方块
Card.Diamond = 4
--- 无花色
Card.NoSuit = 5

---@alias Color integer

--- 黑色
Card.Black = 1
--- 红色
Card.Red = 2
--- 无色
Card.NoColor = 3

---@alias CardType integer

--- 基本牌
Card.TypeBasic = 1
--- 锦囊牌
Card.TypeTrick = 2
--- 装备牌
Card.TypeEquip = 3

---@alias CardSubtype integer

--- 无子类型
Card.SubtypeNone = 1
--- 延时锦囊牌
Card.SubtypeDelayedTrick = 2
--- 武器牌
Card.SubtypeWeapon = 3
--- 防具牌
Card.SubtypeArmor = 4
--- 防御坐骑牌
Card.SubtypeDefensiveRide = 5
--- 进攻坐骑牌
Card.SubtypeOffensiveRide = 6
--- 宝物牌
Card.SubtypeTreasure = 7

---@alias CardArea integer

--- 未知区域
Card.Unknown = 0
--- 手牌区
Card.PlayerHand = 1
--- 装备区
Card.PlayerEquip = 2
--- 判定区
Card.PlayerJudge = 3
--- 武将牌上/旁
Card.PlayerSpecial = 4
--- 处理区
Card.Processing = 5
--- 牌堆
Card.DrawPile = 6
--- 弃牌堆
Card.DiscardPile = 7
--- 移出游戏区
Card.Void = 8

--- Card的构造函数。具体负责构建Card实例的函数，请参见fk_ex部分。
function Card:initialize(name, suit, number, color)
  self.name = name
  self.suit = suit or Card.NoSuit
  self.number = number or 0

  if string.sub(name, 1, 1) == "&" then
    self.name = string.sub(name, 2, #name)
    self.is_derived = true
  end

  local name_splited = self.name:split("__")
  self.trueName = name_splited[#name_splited]

  if suit == Card.Spade or suit == Card.Club then
    self.color = Card.Black
  elseif suit == Card.Heart or suit == Card.Diamond then
    self.color = Card.Red
  elseif color ~= nil then
    self.color = color
  elseif suit == Card.Unknown then
    self.color = Card.Unknown
  else
    self.color = Card.NoColor
  end

  -- self.package = nil
  self.id = 0
  self.virt_id = 0
  self.type = 0
  self.sub_type = Card.SubtypeNone
  -- self.skill = nil
  self.subcards = {}
  self.fake_subcards = {}
  -- self.skillName = nil
  self._skillName = ""
  self.skillNames = {}
  -- self.mark = {}   -- 这个视情况了，只有虚拟牌才有真正的self.mark，真牌的话挂在currentRoom
end

function Card:__index(k)
  if k == "skillName" then
    return self._skillName
  elseif k == "mark" then
    if not self:isVirtual() then
      local mark_tab = Fk:currentRoom().card_marks
      mark_tab[self.id] = mark_tab[self.id] or {}
      return mark_tab[self.id]
    else
      self.mark = {}
      return self.mark
    end
  end
end

function Card:__newindex(k, v)
  if k == "skillName" then
    table.insertIfNeed(self.skillNames, v)
    self._skillName = v
  else
    rawset(self, k, v)
  end
end

function Card:__tostring()
  return string.format("<Card %s[%s %d]>", self.name, self:getSuitString(), self.number)
end

local CBOR_TAG_REAL_CARD = 33002
local CBOR_TAG_VIRTUAL_CARD = 33003

-- 为了节约 不要用string当key
local CBOR_CARD_KEY_NAME = 2
local CBOR_CARD_KEY_SUIT = 3
local CBOR_CARD_KEY_NUMBER = 4
local CBOR_CARD_KEY_COLOR = 5
local CBOR_CARD_KEY_SUBCARDS = 6
local CBOR_CARD_KEY_SKILL_NAMES = 7
local CBOR_CARD_KEY_EXTRA_DATA = 8
local CBOR_CARD_KEY_VIRT_ID = 9
local CBOR_CARD_KEY_MARK = 10

function Card:__tocbor()
  if self.id ~= 0 then
    return cbor.encode(cbor.tagged(CBOR_TAG_REAL_CARD, self.id))
  else
    return cbor.encode(cbor.tagged(
      CBOR_TAG_VIRTUAL_CARD,
      {
        [CBOR_CARD_KEY_NAME] = self.name,
        [CBOR_CARD_KEY_SUIT] = self.suit ~= Card.NoSuit and self.suit or nil,
        [CBOR_CARD_KEY_NUMBER] = self.number ~= 0 and self.number or nil,
        [CBOR_CARD_KEY_COLOR] = self.color ~= Card.NoColor and self.color or nil,
        [CBOR_CARD_KEY_SUBCARDS] = #self.subcards > 0 and self.subcards or nil,
        [CBOR_CARD_KEY_SKILL_NAMES] = #self.skillNames > 0 and self.skillNames or nil,
        [CBOR_CARD_KEY_EXTRA_DATA] = self.extra_data and (
          next(self.extra_data) ~= nil and self.extra_data or nil)
        or nil,
        [CBOR_CARD_KEY_VIRT_ID] = self.virt_id or 0,
        [CBOR_CARD_KEY_MARK] = next(self.mark) ~= nil and self.mark or nil,
      }
    ))
  end
end
function Card:__touistring()
  return self:toLogString()
end
function Card:__toqml()
  local mark = {}
  for k, v in pairs(self.mark) do
    if k and k:startsWith("@") and v and v ~= 0 then
      table.insert(mark, {
        k = k, v = v,
      })
    end
  end

  return {
    uri = "Fk.Components.LunarLTK",
    name = "CardItem",

    prop = {
      cid = self.id,
      virt_id = self.virt_id,
      name = self.name,
      extension = self.package.extensionName,
      number = self.number,
      suit = self:getSuitString(),
      color = self:getColorString(),
      mark = mark,
      type = self.type,
      subtype = self:getSubtypeString(),
      multiple_targets = self.multiple_targets,
    },
  }
end
cbor.tagged_decoders[CBOR_TAG_REAL_CARD] = function(v)
  return Fk:getCardById(v)
end
cbor.tagged_decoders[CBOR_TAG_VIRTUAL_CARD] = function(v)
  local card = Fk:cloneCard(
    v[CBOR_CARD_KEY_NAME],
    v[CBOR_CARD_KEY_SUIT],
    v[CBOR_CARD_KEY_NUMBER]
  )

  card.color = v[CBOR_CARD_KEY_COLOR] or Card.NoColor
  card.subcards = v[CBOR_CARD_KEY_SUBCARDS] or {}
  card.skillNames = v[CBOR_CARD_KEY_SKILL_NAMES] or {}

  card.extra_data = v[CBOR_CARD_KEY_EXTRA_DATA]
  card.virt_id = v[CBOR_CARD_KEY_VIRT_ID] or 0
  card.mark = v[CBOR_CARD_KEY_MARK] or {}

  return card
end

--- 克隆特定卡牌并赋予花色与点数。
---
--- 会将skill/special_skills/equip_skill继承到克隆牌中。
---@param suit? Suit @ 克隆后的牌的花色
---@param number? integer @ 克隆后的牌的点数
---@return Card @ 产品
function Card:clone(suit, number)
  local newCard = self.class:new(self.name, suit, number)
  newCard.skill = self.skill
  newCard.special_skills = self.special_skills
  newCard.is_damage_card = self.is_damage_card
  newCard.multiple_targets = self.multiple_targets
  newCard.stackable_delayed = self.stackable_delayed
  newCard.is_passive = self.is_passive
  newCard.is_derived = self.is_derived
  return newCard
end

--- 检测是否为虚拟卡牌，如果其ID为0，则为虚拟卡牌。
function Card:isVirtual()
  return self.id == 0
end

--- 获取卡牌的ID。
---
--- 如果牌是虚拟牌，则返回其第一张子卡的id，没有子卡就返回nil
---@return integer?
function Card:getEffectiveId()
  if self:isVirtual() then
    return #self.subcards > 0 and self.subcards[1] or nil
  end
  return self.id
end

--- 根据虚拟牌的子卡牌更新牌的颜色、花色和点数
local function updateColorAndNumber(card)
  local color = Card.NoColor
  local number = 0
  for i, id in ipairs(card.subcards) do
    local c = Fk:getCardById(id)
    if i == 1 then
      card.suit = c.suit
      number = math.min(c.number, 13)
      color = c.color
    else
      card.suit = Card.NoSuit
      number = 0

      if color ~= c.color then
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

--- 将一张子卡加入某张牌的虚拟子卡，用于活墨类转化和飞刀判定
---@param card integer|Card @ 要加入的虚拟子卡
function Card:addFakeSubcard(card)
  -- assert(self:isVirtual(), "")
  if type(card) == "number" then
    table.insert(self.fake_subcards, card)
  else
    assert(card:isInstanceOf(Card))
    if card:isVirtual() then
      table.insertTable(self.fake_subcards, card.fake_subcards)
    else
      table.insert(self.fake_subcards, card.id)
    end
  end
end

--- 将一批子卡加入某张牌的虚拟子卡，用于活墨类转化和飞刀判定
---@param cards integer[] | Card[] @ 要加入的虚拟子卡列表
function Card:addFakeSubcards(cards)
  for _, c in ipairs(cards) do
    self:addFakeSubcard(c)
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

--- 获取卡牌花色并返回花色文字描述（如``spade``黑桃、``heart``红桃、``club``梅花、``diamond``方块）或者符号（如♠♥♣♦，带颜色）。
---@param symbol? boolean @ 是否以符号形式显示
---@return string @ 描述花色的字符串
function Card:getSuitString(symbol)
  local suit = self.suit
  local ret = "unknown"
  if suit == Card.Spade then
    ret = "spade"
  elseif suit == Card.Heart then
    ret = "heart"
  elseif suit == Card.Club then
    ret = "club"
  elseif suit == Card.Diamond then
    ret = "diamond"
  elseif suit == Card.NoSuit then
    ret = "nosuit"
  end
  return symbol and "log_" .. ret or ret
end

--- 获取卡牌颜色并返回点数颜色描述（例如``black``黑色/``red``红色/``nocolor``无色）。
---@return string @ 描述颜色的字符串
function Card:getColorString()
  local color = self.color
  if color == Card.Black then
    return "black"
  elseif color == Card.Red then
    return "red"
  elseif color == Card.NoColor then
    return "nocolor"
  end
  return "unknown"
end

--- 获取卡牌类型并返回类型描述（例如``basic``基本牌/``trick``锦囊牌/``equip``装备牌）。
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

local subtype_string_table = {
  [Card.SubtypeArmor] = "armor",
  [Card.SubtypeWeapon] = "weapon",
  [Card.SubtypeTreasure] = "treasure",
  [Card.SubtypeDelayedTrick] = "delayed_trick",
  [Card.SubtypeDefensiveRide] = "defensive_ride",
  [Card.SubtypeOffensiveRide] = "offensive_ride",
}

function Card:getSubtypeString()
  local t = self.sub_type
  local ret = subtype_string_table[t]
  if ret == nil then
    if self.type == Card.TypeTrick then
      return "normal_trick"
    elseif self.type == Card.TypeBasic then
      return "basic"
    end
  else
    return ret
  end
end

--- 获取卡牌点数并返回点数文字描述（仅限A/J/Q/K/X）。
local function getNumberStr(num)
  if num == 1 then
    return "A"
  elseif num == 11 then
    return "J"
  elseif num == 12 then
    return "Q"
  elseif num == 13 then
    return "K"
  elseif num == 0 then
    return "X"
  end
  return tostring(num)
end

--- 获取卡牌点数并返回点数文字描述（仅限A/J/Q/K/X）。
---@param num? integer @ 当你只想翻译点数为文字时(优先检查，请注意)
function Card:getNumberStr(num)
  return tostring(getNumberStr(num and num or self.number))
end

--- 根据点数文字描述返回数字。
---@param str integer @ 只能翻译文字为点数
function Card:strToNumber(str)
  if str == "A" then
    return 1
  elseif str == "J" then
    return 11
  elseif str == "Q" then
    return 12
  elseif str == "K" then
    return 13
  elseif str == "X" then
    return 0
  end
  return tonumber(str)
end

--- 获取卡牌的完整点数(花色+点数)，如（黑桃A/♠A）。
---@param symbol boolean @ 是否以符号形式显示花色
---@return string @ 完整点数（字符串）
function Card:getSuitCompletedString(symbol)
  return Fk:translate(self:getSuitString(symbol)) .. getNumberStr(self.number)
end

--- 判断卡牌是否为普通锦囊牌
---@return boolean
function Card:isCommonTrick()
  return self.type == Card.TypeTrick and self.sub_type ~= Card.SubtypeDelayedTrick
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

--- 为卡牌设置Mark为指定值。设置为0时会清空标记。若需要通知其他玩家，请使用Room:setCardMark
---
--- * @开头的为可见标记，其余为隐藏标记。
---@param mark string @ 标记名词
---@param count any @ 标记值
function Card:setMark(mark, count)
  if count == 0 then count = nil end
  if self.mark[mark] ~= count then
    self.mark[mark] = count
  end
end

--- 获取卡牌对应Mark的数量。
---@param mark string @ 标记
---@return any
function Card:getMark(mark)
  local ret = (self.mark[mark] or 0)
  if (not self:isVirtual()) and next(self.mark) == nil then
    self.mark = nil
  end
  if type(ret) == "table" then
    ret = table.simpleClone(ret)
  end
  return ret
end

--- 获取卡牌有哪些Mark。
function Card:getMarkNames()
  local ret = {}
  for k, _ in pairs(self.mark) do
    table.insert(ret, k)
  end
  return ret
end

--- 检索角色是否拥有指定Mark，考虑后缀(字符串find)。返回检索到的的第一个标记值与标记名
---@param mark string @ 标记名
---@param suffixes? string[] @ 后缀，默认为```MarkEnum.CardTempMarkSuffix```
---@return [any, integer]|nil @ 返回一个表，包含标记值与标记名，或nil
function Card:hasMark(mark, suffixes)
  if suffixes == nil then suffixes = MarkEnum.CardTempMarkSuffix end
  for m, _ in pairs(self.mark) do
    if m == mark then return {self.mark[m], m} end
    if m:startsWith(mark .. "-") then
      local parts = m:split("-")
      if #parts > 1 then
        table.remove(parts, 1) -- 去掉标记名称主体，只留下后缀
        if table.every(parts, function (s)
          return table.contains(suffixes, "-" .. s)
        end) then
          return {self.mark[m], m}
        end
      end
    end
  end
  return nil
end

--- 比较两张卡牌的花色是否相同（无花色牌不与其他任何牌相同）
---@param anotherCard Card @ 另一张卡牌
---@param diff? boolean @ 比较二者不同
---@return boolean @ 返回比较结果
function Card:compareSuitWith(anotherCard, diff)
  if table.contains({ self.suit, anotherCard.suit }, Card.Unknown) then
    return true
  end
  if self ~= anotherCard and table.contains({ self.suit, anotherCard.suit }, Card.NoSuit) then
    return false
  end

  if diff then
    return self.suit ~= anotherCard.suit
  else
    return self.suit == anotherCard.suit
  end
end

--- 比较两张卡牌的颜色是否相同（无颜色牌不与其他任何牌相同）
---@param anotherCard Card @ 另一张卡牌
---@param diff? boolean @ 比较二者不同
---@return boolean @ 返回比较结果
function Card:compareColorWith(anotherCard, diff)
  if table.contains({ self.color, anotherCard.color }, Card.Unknown) then
    return true
  end
  if self ~= anotherCard and table.contains({ self.color, anotherCard.color }, Card.NoColor) then
    return false
  end

  if diff then
    return self.color ~= anotherCard.color
  else
    return self.color == anotherCard.color
  end
end

--- 比较两张卡牌的点数是否相同
---@param anotherCard Card @ 另一张卡牌
---@param diff? boolean @ 比较二者不同
---@return boolean @ 返回比较结果
function Card:compareNumberWith(anotherCard, diff)
  if self ~= anotherCard and (self.number < 1 or anotherCard.number < 1) then
    return false
  end

  if diff then
    return self.number ~= anotherCard.number
  else
    return self.number == anotherCard.number
  end
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
---@param c? integer|integer[]|Card|Card[]
---@return integer[]
function Card:getIdList(c)
  error("This is a static method. Please use Card:getIdList instead")
end

function Card.static:getIdList(c)
  if c == nil then return {} end
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

--- 获得卡牌的标记并初始化为表
---@param mark string @ 标记
---@return table
function Card:getTableMark(mark)
  local ret = self:getMark(mark)
  return type(ret) == "table" and ret or {}
end


--- 获得使用此牌的固定目标，仅有不能自由选择目标的牌会有固定目标。即桃、无中、装备、AOE等
---@param player Player @ 使用者
---@param extra_data? UseExtraData @ 额外数据
---@return Player[]|nil @ 返回固定目标角色列表。若此牌可以选择目标，返回空值
function Card:getFixedTargets(player, extra_data)
  local ret = extra_data and extra_data.fix_targets
  if ret then return table.map(ret, Util.Id2PlayerMapper) end
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable---@type TargetModSkill[]
  for _, skill in ipairs(status_skills) do
    local targetIds = skill:getFixedTargets(player, self.skill, self, extra_data)
    if targetIds then
      return table.map(targetIds, Util.Id2PlayerMapper)
    end
  end
  -- 卡牌自身赋予的默认目标
  ret = self.skill:fixTargets(player, self, extra_data)
  if ret then return ret end
  -- 以下为适用所有牌的默认值
  if self.skill:getMinTargetNum(player) == 0 and not self.is_passive then
    -- 此处仅作为默认值，若与默认选择规则不一致（如火烧连营）请修改cardSkill的fix_targets参数
    if self.multiple_targets then
      return table.filter(Fk:currentRoom().alive_players, function (p)
        return self.skill:modTargetFilter(player, p, {}, self)
      end)
    else
      return {player}
    end
  end
  return nil
end


--- 获得使用一张牌的所有合法目标角色表。用于判断一张必须使用的牌能否使用
---
--- eg.杀返回攻击范围内***所有***角色，桃返回自己，濒死桃返回目标濒死角色，借刀杀人***返回目标角色不返回子目标***
---@param player Player @ 使用者
---@param extra_data? UseExtraData|table
---@return Player[] @ 返回目标角色表
function Card:getAvailableTargets (player, extra_data)
  if not player:canUse(self, extra_data) or player:prohibitUse(self) then return {} end
  extra_data = extra_data or Util.DummyTable
  local room = Fk:currentRoom()
  -- 选定目标的优先逻辑：额外的锁定目标(求桃锁定濒死角色)>牌本身的锁定目标(南蛮无中装备)>所有角色
  local avail = (self:getFixedTargets(player, extra_data) or room.alive_players)
  local tos = table.simpleClone(avail)
  -- 过滤额外的目标限制
  for _, limit in ipairs({"exclusive_targets", "must_targets", "include_targets"}) do
    if type(extra_data[limit]) == "table" and #extra_data[limit] > 0 then
      tos = table.filter(tos, function(p) return table.contains(extra_data[limit], p.id) end)
    end
  end
  if #tos == 0 then return {} end
  tos = table.filter(tos, function(p)
    return not player:isProhibited(p, self) and self.skill:modTargetFilter(player, p, {}, self, extra_data)
  end)
  local n = self.skill:getMinTargetNum(player)
  if n > 1 then
    if n == 2 then
      for i = #tos, 1, -1 do
        if not table.find(room.alive_players, function (p)
          return p ~= tos[i] and self.skill:targetFilter(player, p, {tos[i]}, {}, self, extra_data)
        end) then
          table.remove(tos, i)
        end
      end
    else
      --最小目标过多则直接当作没有复杂规则，每个目标平权。eg.荆襄盛世
      if #tos >= n then
        return table.random(tos, n)
      else
        return {}
      end
    end
  end
  return tos
end


-- 获得使用一张牌的一个可能的指定方式。
---
---用于判断一张必须使用的牌能否使用，或给一张必须使用的牌添加默认目标。
---
--- eg.杀返回攻击范围内***一个***合法目标，借刀杀人返回***一对***角色，南蛮入侵返回***所有***其他角色
---@param player Player @ 使用者
---@param extra_data? UseExtraData|table
---@return Player[] @ 目标角色表。返回空表表示无合法目标
function Card:getDefaultTarget (player, extra_data)
  extra_data = extra_data or Util.DummyTable
  local tos = self:getAvailableTargets(player, extra_data)
  if #tos == 0 then return {} end
  local n = self.skill:getMinTargetNum(player)
  if n == 0 then
    return tos
  elseif n == 2 then
    for i = #tos, 1, -1 do
      for _, p in ipairs(Fk:currentRoom().alive_players) do
        if p ~= tos[i] and self.skill:targetFilter(player, p, {tos[i]}, {}, self, extra_data) then
          return {tos[i], p}
        end
      end
    end
  else
    return table.random(tos, n)
  end
  return {}
end

--- 给卡牌赋予skillname，并赋予pattern（适用于转化技在合法性判断时未确定实体牌的情况）
---@param skillName string?
---@param player Player?
---@param pattern string?
function Card:setVSPattern(skillName, player, pattern)
  if skillName then
    self.skillName = skillName
  end
  if pattern then
    self:setMark("Global_VS_Pattern", pattern)
  else
    local skill = Fk.skills[skillName]---@type ViewAsSkill
    if skill:isInstanceOf(ViewAsSkill) then
      local vs = player and skill:filterPattern(player, self.name, self.subcards) or nil
      if vs and vs.subcards then
        self:addSubcards(vs.subcards)
        return
      end
      local exp = Exppattern:Parse(skill.pattern or ".")
      local matchers = {}
      for _, m in ipairs(exp.matchers) do
        if (m.name == nil or table.contains(m.name, self.name)) and
          (m.trueName == nil or table.contains(m.trueName, self.trueName)) then
          --因为牌名信息已确认，直接指定之即可
          --FIXME: 未考虑neg（似乎暂时用不到？）
          m.name = { self.name }
          m.trueName = { self.trueName }

          if vs then
            local single_exp = Exppattern:Parse(vs.pattern)
            local e_suits, e_colors, e_numbers = {}, {}, {}
            local suit_strings = {"spade", "club", "heart", "diamond", "nosuit"}
            local color_strings = {"black", "red", "nocolor"}

            for i = math.max(vs.min_num, #self.subcards), vs.max_num, 1 do
              if i == 0 then
                table.insert(e_suits, "nosuit")
                table.insert(e_colors, "nocolor")
                table.insert(e_numbers, 0)
              elseif i == 1 then
                if #self.subcards == 1 then
                  table.insertIfNeed(e_suits, self:getSuitString())
                  table.insertIfNeed(e_colors, self:getColorString())
                  table.insertIfNeed(e_numbers, self.number)
                else
                  for _, suit_str in ipairs(color_strings) do
                    if single_exp:matchExp(".|.|" .. suit_str) then
                      table.insertIfNeed(e_colors, suit_str)
                    end
                  end
                  for _, suit_str in ipairs(suit_strings) do
                    if single_exp:matchExp(".|.|" .. suit_str) then
                      table.insertIfNeed(e_suits, suit_str)
                    end
                  end
                  if #e_numbers == 0 and single_exp:matchExp(".|0") then
                    table.insert(e_numbers, 0)
                  end
                  for j = 1, 13, 1 do
                    if single_exp:matchExp(".|" .. tostring(j)) then
                      table.insert(e_numbers, j)
                    end
                  end
                end
              else
                if e_suits then
                  table.insertIfNeed(e_suits, "nosuit")
                end
                if e_numbers then
                  table.insertIfNeed(e_numbers, 0)
                end
                --FIXME:需考虑已有的subcards
                local hasRed = single_exp:matchExp(".|.|red")
                local hasBlack = single_exp:matchExp(".|.|black")
                if #self.subcards > 0 then
                  if self.color == Card.Red then
                    hasRed = true
                  elseif self.color == Card.Black then
                    hasBlack = true
                  else
                    table.insertIfNeed(e_colors, "nocolor")
                    break
                  end
                end
                if hasRed then
                  table.insertIfNeed(e_colors, "red")
                end
                if hasBlack then
                  table.insertIfNeed(e_colors, "black")
                end

                if (hasRed and hasBlack) or single_exp:matchExp(".|.|nocolor") then
                  table.insertIfNeed(e_colors, "nocolor")
                end

                break
              end
            end
            if m.suit == nil then
              m.suit = table.connect(e_suits, e_colors)
            end
            if m.number == nil and #e_numbers < 14 then
              m.number = e_numbers
            end
          end
          table.insert(matchers, m)
        end
      end
      pattern = tostring(exp)
      self:setMark("Global_VS_Pattern", pattern)
    end
  end
end

function Card:getVSPattern()
  local vs_pattern = self:getMark("Global_VS_Pattern")
  if type(vs_pattern) == "string" then
    return vs_pattern
  end
end

--- 判断此牌能否符合一个卡牌规则（适用于转化技在合法性判断时未确定实体牌的情况）
function Card:matchVSPattern(pattern)
  local vs_pattern = self:getMark("Global_VS_Pattern")
  if type(vs_pattern) == "string" then
    return Exppattern:Parse(vs_pattern):matchExp(pattern)
  end
  return Exppattern:Parse(pattern):match(self)
end

return Card
