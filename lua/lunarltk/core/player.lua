-- SPDX-License-Identifier: GPL-3.0-or-later

local basePlayer = require "core.player"

--- 玩家分为客户端要处理的玩家，以及服务端处理的玩家两种。
---
--- 客户端能知道的玩家的信息十分有限，而服务端知道一名玩家的所有细节。
---
--- Player类就是这两种玩家的基类，包含它们共用的部分。
---
---@class Player : Base.Player
---@field public hp integer @ 体力值
---@field public maxHp integer @ 体力上限
---@field public shield integer @ 护甲数
---@field public kingdom string @ 势力
---@field public role_shown boolean @ 身份是否明置
---@field public general string @ 武将
---@field public deputyGeneral string @ 副将
---@field public gender integer @ 性别
---@field public phase Phase @ 当前阶段
---@field public faceup boolean @ 是否正面朝上
---@field public chained boolean @ 是否处于连环状态
---@field public dying boolean @ 是否处于濒死
---@field public dead boolean @ 是否死亡
---@field public player_skills Skill[] @ 当前拥有的所有技能
---@field public derivative_skills table<Skill, Skill[]> @ 角色派生技能，键为使获得此派生技能的源技能，值为派生技能表
---@field private _fake_skills Skill[]
---@field public flag string[] @ 当前拥有的flag，不过好像没用过
---@field public tag table<string, any> @ 当前拥有的所有tag，好像也没用过
---@field public player_cards table<integer, integer[]> @ 当前拥有的所有牌，键是区域，值是id列表
---@field public virtual_equips Card[] @ 当前的虚拟装备牌，其实也包含着虚拟延时锦囊这种
---@field public special_cards table<string, integer[]> @ 类似“屯田”的“田”的私人牌堆
---@field public cardUsedHistory table<string, integer[]> @ 用牌次数历史记录
---@field public skillUsedHistory table<string, integer[]> @ 发动技能次数的历史记录
---@field public skillBranchUsedHistory table<string, table<string, integer[]>> @ 发动技能某分支次数的历史记录
---@field public buddy_list integer[] @ 队友列表，或者说自己可以观看别人手牌的那些玩家的列表
---@field public equipSlots string[] @ 装备栏列表
---@field public sealedSlots string[] @ 被废除的装备栏列表
local Player = basePlayer:subclass("Player")

---@class Player
---@field public next Player

---@alias Phase integer

Player.RoundStart = 1
Player.Start = 2
Player.Judge = 3
Player.Draw = 4
Player.Play = 5
Player.Discard = 6
Player.Finish = 7
Player.NotActive = 8
Player.PhaseNone = 9

---@alias PlayerCardArea integer

Player.Hand = 1
Player.Equip = 2
Player.Judge = 3
Player.Special = 4

Player.HistoryPhase = 1
Player.HistoryTurn = 2
Player.HistoryRound = 3
Player.HistoryGame = 4

Player.WeaponSlot = 'WeaponSlot'
Player.ArmorSlot = 'ArmorSlot'
Player.OffensiveRideSlot = 'OffensiveRideSlot'
Player.DefensiveRideSlot = 'DefensiveRideSlot'
Player.TreasureSlot = 'TreasureSlot'
Player.JudgeSlot = 'JudgeSlot'

function Player:initialize()
  basePlayer.initialize(self)

  table.insertTable(self.property_keys, {
    "general", "deputyGeneral", "maxHp", "hp", "shield", "gender", "kingdom",
    "dead", "role_shown", "rest", "phase", "faceup", "chained",
    "equipSlots", "sealedSlots",

    "surrendered",
  })
  self.hp = 0
  self.maxHp = 0
  self.kingdom = "qun"
  self.general = ""
  self.deputyGeneral = ""
  self.gender = General.Male
  self.phase = Player.NotActive
  self.faceup = true
  self.chained = false
  self.dying = false
  self.dead = false
  self.drank = 0
  self.rest = 0

  self.player_skills = {}
  self.derivative_skills = {}
  self._fake_skills = {}
  self.flag = {}
  self.tag = {}
  self.player_cards = {
    [Player.Hand] = {},
    [Player.Equip] = {},
    [Player.Judge] = {},
  }
  self.special_cards = {}
  self.virtual_equips = {}

  self.equipSlots = {
    Player.WeaponSlot,
    Player.ArmorSlot,
    Player.OffensiveRideSlot,
    Player.DefensiveRideSlot,
    Player.TreasureSlot,
  }
  self.sealedSlots = {}

  self.cardUsedHistory = {}
  self.skillUsedHistory = {}
  self.skillBranchUsedHistory = {}
  self.buddy_list = {}
end

function Player:__tostring()
  return string.format("<%s %d>", self.id < 0 and "Bot" or "Player", math.abs(self.id))
end

local CBOR_TAG_PLAYER = 33001
function Player:__tocbor()
  return cbor.encode(cbor.tagged(CBOR_TAG_PLAYER, self.id))
end
function Player:__touistring()
  if self.deputyGeneral == "" then
    return Fk:translate(self.general)
  end
  return Fk:translate("seat#" .. self.seat)
end
function Player:__toqml()
  return {
    uri = "Fk.Components.LunarLTK",
    name = "PhotoBase",

    -- 屋檐了，烂QML
    prop = {
      playerid = self.id,
      scale = 0.55,
      general = self.general,
      deputyGeneral = self.deputyGeneral,
      role = self.role,
      state = "candidate",
      avatar = self.player:getAvatar(),
      screenName = self.player:getScreenName(),
      kingdom = self.kingdom,
      seatNumber = self.seat == 0 and 1 or self.seat,
      selectable = true,
    },
  }
end

cbor.tagged_decoders[CBOR_TAG_PLAYER] = function(v)
  return Fk:currentRoom():getPlayerById(v)
end

--- 设置角色、体力、技能。
---@param general General @ 角色类型
---@param setHp? boolean @ 是否设置体力
---@param addSkills? boolean @ 是否增加技能
---@deprecated
function Player:setGeneral(general, setHp, addSkills)
  self.general = general.name
  if setHp then
    self.maxHp = general.maxHp
    self.hp = general.hp
  end

  if addSkills then
    table.insertTableIfNeed(self.player_skills, general:getSkillNameList())
  end
end

--- 根据角色的主副将计算角色的体力上限
function Player:getGeneralMaxHp()
  local general = Fk.generals[type(self:getMark("__heg_general")) == "string" and self:getMark("__heg_general") or self.general]
  local deputy = Fk.generals[type(self:getMark("__heg_deputy")) == "string" and self:getMark("__heg_deputy") or self.deputyGeneral]

  if not deputy then
    return general.maxHp + general.mainMaxHpAdjustedValue
  else
    return (general.maxHp + general.mainMaxHpAdjustedValue + deputy.maxHp + deputy.deputyMaxHpAdjustedValue) // 2
  end
end

--- 查询角色是否存在flag。
---@param flag string @ 一种标记
---@deprecated @ 用mark代替
function Player:hasFlag(flag)
  return table.contains(self.flag, flag)
end

--- 为角色赋予flag。
---@param flag string @ 一种标记
---@deprecated @ 用mark代替
function Player:setFlag(flag)
  if flag == "." then
    self:clearFlags()
    return
  end
  if flag:sub(1, 1) == "-" then
    flag = flag:sub(2, #flag)
    table.removeOne(self.flag, flag)
    return
  end
  if not self:hasFlag(flag) then
    table.insert(self.flag, flag)
  end
end

--- 清除角色flag。
function Player:clearFlags()
  self.flag = {}
end

--- 将指定数量的牌加入玩家的对应区域。
---@param playerArea PlayerCardArea @ 玩家牌所在的区域
---@param cardIds integer[] @ 牌的ID，返回唯一牌
---@param specialName? string @ 私人牌堆名
function Player:addCards(playerArea, cardIds, specialName)
  assert(table.contains({ Player.Hand, Player.Equip, Player.Judge, Player.Special }, playerArea))
  assert(playerArea ~= Player.Special or type(specialName) == "string")

  if playerArea == Player.Special then
    self.special_cards[specialName] = self.special_cards[specialName] or {}
    table.insertTable(self.special_cards[specialName], cardIds)
  else
    table.insertTable(self.player_cards[playerArea], cardIds)
  end
end

--- 将指定数量的牌移除出玩家的对应区域。
---@param playerArea PlayerCardArea @ 玩家牌所在的区域
---@param cardIds integer[] @ 牌的ID，返回唯一牌
---@param specialName? string @ 私人牌堆名
function Player:removeCards(playerArea, cardIds, specialName)
  assert(table.contains({ Player.Hand, Player.Equip, Player.Judge, Player.Special }, playerArea))
  assert(playerArea ~= Player.Special or type(specialName) == "string")

  local fromAreaIds = playerArea == Player.Special and self.special_cards[specialName] or self.player_cards[playerArea]
  if fromAreaIds then
    for _, id in ipairs(cardIds) do
      if #fromAreaIds == 0 then
        break
      end
      if not table.removeOne(fromAreaIds, id) and not table.removeOne(fromAreaIds, -1) then
        table.remove(fromAreaIds, 1)
      end
    end
  end
end

-- virtual delayed trick can use these functions too

--- 为玩家提供虚拟装备。
---@param card Card @ 卡牌
function Player:addVirtualEquip(card)
  assert(card and card:isInstanceOf(Card) and card:isVirtual())
  table.insertIfNeed(self.virtual_equips, card)
end

--- 为玩家移除虚拟装备。
---@param cid integer @ 卡牌ID，用来定位装备
function Player:removeVirtualEquip(cid)
  for _, c in ipairs(self.virtual_equips) do
    for _, id in ipairs(c.subcards) do
      if id == cid then
        table.removeOne(self.virtual_equips, c)
        return c
      end
    end
  end
end

--- 确认玩家是否存在虚拟装备。
---@param cid integer @ 卡牌ID，用来定位装备
---@return Card?
function Player:getVirtualEquip(cid)
  for _, c in ipairs(self.virtual_equips) do
    for _, id in ipairs(c.subcards) do
      if id == cid then
        return c
      end
    end
  end
  return nil
end

---@deprecated
Player.getVirualEquip = Player.getVirtualEquip

--- 确认玩家判定区是否存在延迟锦囊牌。
---@return boolean
function Player:hasDelayedTrick(card_name)
  for _, id in ipairs(self:getCardIds(Player.Judge)) do
    local c = self:getVirtualEquip(id)
    if not c then c = Fk:getCardById(id) end
    if c.name == card_name then
      return true
    end
  end
  return false
end

--- 获取玩家特定区域所有牌的ID。
---@param playerAreas? PlayerCardArea|PlayerCardArea[]|string @ 玩家牌所在的区域
---@param specialName? string @私人牌堆名
---@return integer[] @ 返回对应区域的所有牌对应的ID
function Player:getCardIds(playerAreas, specialName)
  local rightAreas = { Player.Hand, Player.Equip, Player.Judge }
  playerAreas = playerAreas or rightAreas
  local cardIds = {}
  if type(playerAreas) == "string" then
    local str = playerAreas
    playerAreas = {}
    if str:find("h") then
      table.insert(playerAreas, Player.Hand)
    end
    if str:find("&") then--增加特殊区域
      for k, v in pairs(self.special_cards) do
        if k:endsWith("&") then table.insertTable(cardIds, v) end
      end
    end
    if str:find("e") then
      table.insert(playerAreas, Player.Equip)
    end
    if str:find("j") then
      table.insert(playerAreas, Player.Judge)
    end
  end
  assert(type(playerAreas) == "number" or type(playerAreas) == "table")
  local areas = type(playerAreas) == "table" and playerAreas or { playerAreas }

  rightAreas = { Player.Hand, Player.Equip, Player.Judge, Player.Special }
  for _, area in ipairs(areas) do
    assert(table.contains(rightAreas, area))
    assert(area ~= Player.Special or type(specialName) == "string")
    local currentCardIds = area == Player.Special and self.special_cards[specialName] or self.player_cards[area]
    table.insertTable(cardIds, currentCardIds)
  end

  return cardIds
end

--- 通过名字检索获取玩家对应的私人牌堆。没有为{}。
---@param name string @ 私人牌堆名
---@return integer[]
function Player:getPile(name)
  return table.simpleClone(self.special_cards[name] or {})
end

--- 通过ID检索获取玩家对应的私人牌堆。
---@param id integer @ 私人牌堆ID
---@return string?
function Player:getPileNameOfId(id)
  for k, v in pairs(self.special_cards) do
    if table.contains(v, id) then return k end
  end
end

--- 返回所有名字以“&”结尾（如手牌般使用或打出）的pile的牌。
--- 提示：VSSkill中需要```handly_pile = true```才能使用这些牌。
---@param include_hand? boolean @ 是否包含真正的手牌，默认包含
---@return integer[]
function Player:getHandlyIds(include_hand)
  include_hand = include_hand or include_hand == nil
  local ret = include_hand and self:getCardIds("h") or {}
  for k, v in pairs(self.special_cards) do
    if k:endsWith("&") then table.insertTable(ret, v) end
  end
  local filterSkills = Fk:currentRoom().status_skills[FilterSkill] or Util.DummyTable ---@type FilterSkill[]
  for _, filter in ipairs(filterSkills) do
    local ids = filter:handlyCardsFilter(self)
    if ids then
      table.insertTableIfNeed(ret, ids)
    end
  end
  return ret
end

-- for fkp only
--- 获取手牌数
---@return integer
function Player:getHandcardNum()
  return #self:getCardIds(Player.Hand)
end

function Player:filterHandcards()
  for _, id in ipairs(self:getCardIds(Player.Hand)) do
    Fk:filterCard(id, self)
  end
end

--- 检索玩家装备区是否存在对应类型的装备。
---
--- 注意：带转化信息应使用```getEquipCards```
---@param cardSubtype CardSubtype @ 卡牌子类
---@return integer? @ 返回卡牌ID或nil
function Player:getEquipment(cardSubtype)
  for _, cardId in ipairs(self.player_cards[Player.Equip]) do
    local c = self:getVirtualEquip(cardId) or Fk:getCardById(cardId)
    if c.sub_type == cardSubtype then
      return cardId
    end
  end

  return nil
end

--- 检索玩家装备区是否存在对应类型或所有类型的装备列表。
---
--- 注意：带转化信息应使用```getEquipCards```
---@param cardSubtype? CardSubtype @ 卡牌子类，不填则返回所有装备
---@return integer[] @ 返回id数组或空表
function Player:getEquipments(cardSubtype)
  local cardIds = {}
  for _, cardId in ipairs(self.player_cards[Player.Equip]) do
    if cardSubtype == nil or (self:getVirtualEquip(cardId) or Fk:getCardById(cardId)).sub_type == cardSubtype then
      table.insert(cardIds, cardId)
    end
  end

  return cardIds
end

--- 检索玩家装备区是否存在对应类型的装备列表。（带转化信息）
---@param cardSubtype? CardSubtype @ 卡牌子类，不填则返回所有装备
---@return Card[] @ 返回卡牌数组或空表
function Player:getEquipCards(cardSubtype)
  local cards = {}
  local card
  for _, cardId in ipairs(self.player_cards[Player.Equip]) do
    card = self:getVirtualEquip(cardId) or Fk:getCardById(cardId)
    if cardSubtype == nil or card.sub_type == cardSubtype then
      table.insert(cards, card)
    end
  end
  return cards
end

--- 检索玩家判定区是否存在对应的延时锦囊列表。（带转化信息）
---@param name? string @ 延时锦囊卡名，不填则返回所有延时锦囊
---@return Card[] @ 返回卡牌数组或空表
function Player:getDelayedTrickCards(name)
  local cards = {}
  for _, cardId in ipairs(self.player_cards[Player.Judge]) do
    local card = self:getVirtualEquip(cardId) or Fk:getCardById(cardId)
    if name == nil or card.trueName == name then
      table.insert(cards, card)
    end
  end
  return cards
end

--- 获取玩家手牌上限。
---@return integer
function Player:getMaxCards()
  local baseValue = math.max(self.hp, 0)

  local status_skills = Fk:currentRoom().status_skills[MaxCardsSkill] or Util.DummyTable
  local max_fixed = nil
  for _, skill in ipairs(status_skills) do
    local f = skill:getFixed(self)
    if f ~= nil then
      max_fixed = max_fixed and math.max(max_fixed, f) or f
    end
  end

  if max_fixed then baseValue = math.max(max_fixed, 0) end

  for _, skill in ipairs(status_skills) do
    local c = skill:getCorrect(self)
    baseValue = baseValue + (c or 0)
  end

  return math.max(baseValue, 0)
end

--- 获取玩家攻击范围。
---@param excludeIds? integer[] @ 忽略的自己装备的id列表
---@param excludeSkills? string[] @ 忽略的技能名列表
---@return integer
function Player:getAttackRange(excludeIds, excludeSkills)
  local baseValue = 1

  local weapons = table.filter(self:getEquipments(Card.SubtypeWeapon), function (id)
    if not table.contains(excludeIds or {}, id) then
      local weapon = self:getVirtualEquip(id) or Fk:getCardById(id) ---@class Weapon
      return weapon:AvailableAttackRange(self)
    end
  end)
  if #weapons > 0 then
    baseValue = 0
    for _, id in ipairs(weapons) do
      local weapon = self:getVirtualEquip(id) or Fk:getCardById(id) ---@class Weapon
      baseValue = math.max(baseValue, weapon:getAttackRange(self) or 1)
    end
  end

  excludeSkills = excludeSkills or {}
  if excludeIds then
    for _, id in ipairs(excludeIds) do
      local equip = self:getVirtualEquip(id) --[[@as EquipCard]]
      if equip == nil and table.contains(self:getCardIds("e"), id) and Fk:getCardById(id).type == Card.TypeEquip then
        equip = Fk:getCardById(id) --[[@as EquipCard]]
      end
      if equip and equip.type == Card.TypeEquip then
        for _, skill in ipairs(equip:getEquipSkills(self)) do
          table.insertIfNeed(excludeSkills, skill.name)
        end
      end
    end
  end

  local status_skills = Fk:currentRoom().status_skills[AttackRangeSkill] or Util.DummyTable ---@type AttackRangeSkill[]
  local max_fixed, correct = nil, 0
  for _, skill in ipairs(status_skills) do
    if not table.contains(excludeSkills, skill.name) then
      local final = skill:getFinal(self)
      if final then -- 目前逻辑，发现一个终值马上返回
        return math.max(0, final)
      end
      local f = skill:getFixed(self)
      if f ~= nil then
        max_fixed = max_fixed and math.max(max_fixed, f) or f
      end
      local c = skill:getCorrect(self)
      correct = correct + (c or 0)
    end
  end

  return math.max(math.max(baseValue, (max_fixed or 0)) + correct, 0)
end

--- 获取角色是否被移除。
---@return boolean
function Player:isRemoved()
  for mark, _ in pairs(self.mark) do
    if mark == MarkEnum.PlayerRemoved then return true end
    if mark:startsWith(MarkEnum.PlayerRemoved .. "-") then
      for _, suffix in ipairs(MarkEnum.TempMarkSuffix) do
        if mark:find(suffix, 1, true) then return true end
      end
    end
  end
end

--- 获取玩家与其他角色的实际距离。
---
--- 通过 二者位次+距离技能之和 与 两者间固定距离 进行对比，更大的为实际距离。
---
--- 注意比较距离时使用```Player:compareDistance()```。
---@param other Player @ 其他玩家
---@param mode? string @ 计算模式(left/right/both)
---@param ignore_dead? boolean @ 是否忽略尸体
---@param excludeIds? integer[] @ 忽略的自己装备的id列表，用于飞刀判定
---@param excludeSkills? string[] @ 忽略的技能名列表
function Player:distanceTo(other, mode, ignore_dead, excludeIds, excludeSkills)
  assert(other:isInstanceOf(Player))
  mode = mode or "both"
  excludeSkills = excludeSkills or {}
  if excludeIds then
    for _, id in ipairs(excludeIds) do
      local equip = self:getVirtualEquip(id) --[[@as EquipCard]]
      if equip == nil and table.contains(self:getCardIds("e"), id) and Fk:getCardById(id).type == Card.TypeEquip then
        equip = Fk:getCardById(id) --[[@as EquipCard]]
      end
      if equip and equip.type == Card.TypeEquip then
        for _, skill in ipairs(equip:getEquipSkills(self)) do
          table.insertIfNeed(excludeSkills, skill.name)
        end
      end
    end
  end
  if other == self then return 0 end
  if not ignore_dead and other.dead then
    return -1
  end
  if self:isRemoved() or other:isRemoved() then
    return -1
  end
  local right = 0
  local temp = self
  local try_time = 10
  for _ = 0, try_time do
    if temp == other then break end
    if (ignore_dead or not temp.dead) and not temp:isRemoved() then
      right = right + 1
    end
    temp = temp.next
  end
  if temp ~= other then
    print("Distance malfunction: start and end does not match.")
  end
  local left = #(ignore_dead and Fk:currentRoom().players or Fk:currentRoom().alive_players) - right - #table.filter(Fk:currentRoom().alive_players, function(p) return p:isRemoved() end)
  local ret = 0
  if mode == "left" then
    ret = left
  elseif mode == "right" then
    ret = right
  else
    ret = math.min(left, right)
  end

  local status_skills = Fk:currentRoom().status_skills[DistanceSkill] or Util.DummyTable  ---@type DistanceSkill[]
  for _, skill in ipairs(status_skills) do
    if not table.contains(excludeSkills, skill.name) then
      local fixed = skill:getFixed(self, other)
      local correct = skill:getCorrect(self, other)
      if fixed ~= nil then
        ret = fixed
        break
      end
      ret = ret + (correct or 0)
    end
  end

  return math.max(ret, 1)
end

--- 比较距离（排除移出游戏（-1），故一般仅当<与<=时使用此函数有价值）
---@param other Player @ 终点角色
---@param num integer @ 比较基准
---@param operator "<"|">"|"<="|">="|"=="|"~=" @ 运算符
---@return boolean @ 返回比较结果，不计入距离结果永远为false
function Player:compareDistance(other, num, operator)
  local distance = self:distanceTo(other)
  if distance < 0 or num < 0 then return false end
  if operator == ">" then
    return distance > num
  elseif operator == "<" then
    return distance < num
  elseif operator == "==" then
    return distance == num
  elseif operator == ">=" then
    return distance >= num
  elseif operator == "<=" then
    return distance <= num
  elseif operator == "~=" then
    return distance ~= num
  end
  return false
end

--- 获取其他玩家是否在玩家的攻击范围内。
---@param other Player @ 其他玩家
---@param fixLimit? integer @ 卡牌距离限制增加专用
---@param excludeIds? integer[] @ 忽略的自己装备的id列表，用于飞刀判定
---@param excludeSkills? string[] @ 忽略的技能名列表
---@return boolean
function Player:inMyAttackRange(other, fixLimit, excludeIds, excludeSkills)
  assert(other:isInstanceOf(Player))
  if self == other or (other and (other.dead or other:isRemoved())) or self:isRemoved() then
    return false
  end

  fixLimit = fixLimit or 0
  excludeSkills = excludeSkills or {}
  if excludeIds then
    for _, id in ipairs(excludeIds) do
      local equip = self:getVirtualEquip(id) --[[@as EquipCard]]
      if equip == nil and table.contains(self:getCardIds("e"), id) and Fk:getCardById(id).type == Card.TypeEquip then
        equip = Fk:getCardById(id) --[[@as EquipCard]]
      end
      if equip and equip.type == Card.TypeEquip then
        for _, skill in ipairs(equip:getEquipSkills(self)) do
          table.insertIfNeed(excludeSkills, skill.name)
        end
      end
    end
  end

  local status_skills = Fk:currentRoom().status_skills[AttackRangeSkill] or Util.DummyTable ---@type AttackRangeSkill[]
  for _, skill in ipairs(status_skills) do
    if not table.contains(excludeSkills, skill.name) and skill:withoutAttackRange(self, other) then
      return false
    end
  end
  for _, skill in ipairs(status_skills) do
    if not table.contains(excludeSkills, skill.name) and skill:withinAttackRange(self, other) then
      return true
    end
  end

  local baseAttackRange = self:getAttackRange(excludeIds, excludeSkills)
  return self:distanceTo(other, nil, nil, excludeIds, excludeSkills) <= (baseAttackRange + fixLimit)
end

--- 获取下家。
---@param ignoreRemoved? boolean @ 忽略被移除
---@param num? integer @ 第几个，默认1
---@param ignoreRest? boolean @ 是否忽略休整
---@return Player
function Player:getNextAlive(ignoreRemoved, num, ignoreRest)
  if #Fk:currentRoom().alive_players == 0 then
    return self.rest > 0 and self.next.rest > 0 and self.next or self
  end
  local doNotIgnore = not ignoreRemoved
  if doNotIgnore and table.every(Fk:currentRoom().alive_players, function(p) return p:isRemoved() end) then
    return self
  end

  local ret = self
  num = num or 1
  for _ = 1, num do
    ret = ret.next
    while (ret.dead and (ret.rest == 0 or not ignoreRest)) or (doNotIgnore and ret:isRemoved()) do
      ret = ret.next
    end
  end
  return ret
end

--- 获取上家。
---@param ignoreRemoved? boolean @ 忽略被移除
---@param num? integer @ 第几个，默认1
---@param ignoreRest? boolean @ 是否忽略休整
---@return Player
function Player:getLastAlive(ignoreRemoved, num, ignoreRest)
  num = num or 1
  local alive_players = table.filter(Fk:currentRoom().players, function(p) return (not p.dead or (p.rest > 0 and ignoreRest)) and (ignoreRemoved or not p:isRemoved()) end)
  local index = #alive_players - num
  return self:getNextAlive(ignoreRemoved, index, ignoreRest)
end

--- 增加玩家使用特定牌的历史次数。
---@param cardName string @ 牌名
---@param num? integer @ 次数
function Player:addCardUseHistory(cardName, num)
  num = num or 1
  assert(type(num) == "number" and num ~= 0)

  self.cardUsedHistory[cardName] = self.cardUsedHistory[cardName] or {0, 0, 0, 0}
  local t = self.cardUsedHistory[cardName]
  for i, _ in ipairs(t) do
    t[i] = t[i] + num
  end
end

--- 设定玩家使用特定牌的历史次数。
---@param cardName string @ 牌名
---@param num? integer @ 次数 默认0
---@param scope? integer @ 历史范围 全为nil意为清空
function Player:setCardUseHistory(cardName, num, scope)
  if cardName == "" and num == nil and scope == nil then
    self.cardUsedHistory = {}
    return
  end

  num = num or 0
  if cardName == "" then
    for _, v in pairs(self.cardUsedHistory) do
      v[scope] = num
    end
    return
  end

  if self.cardUsedHistory[cardName] then
    self.cardUsedHistory[cardName][scope] = num
  end
end

--- 增加玩家使用特定技能的历史次数。
---@param skill_name string @ 技能名
---@param num? integer @ 次数 默认1
function Player:addSkillUseHistory(skill_name, num)
  num = num or 1
  assert(type(num) == "number" and num ~= 0)

  self.skillUsedHistory[skill_name] = self.skillUsedHistory[skill_name] or {0, 0, 0, 0}
  local t = self.skillUsedHistory[skill_name]
  for i, _ in ipairs(t) do
    t[i] = t[i] + num
  end
end

--- 增加玩家使用特定技能分支的历史次数。
---@param skill_name string @ 技能名
---@param branch string @ 技能分支名，不写则默认改变某技能**所有分支**的历史次数
---@param num? integer @ 次数 默认1
function Player:addSkillBranchUseHistory(skill_name, branch, num)
  num = num or 1
  assert(type(num) == "number" and num ~= 0)

  self.skillBranchUsedHistory[skill_name] = self.skillBranchUsedHistory[skill_name] or {}
  self.skillBranchUsedHistory[skill_name][branch] = self.skillBranchUsedHistory[skill_name][branch] or {0, 0, 0, 0}
  local t = self.skillBranchUsedHistory[skill_name][branch]
  for i, _ in ipairs(t) do
    t[i] = t[i] + num
  end
end

--- 设定玩家使用特定技能的历史次数。
--- `num`和`scope`均不写则为清空特定区域的历史次数
---@param skill_name? string @ 技能名，不写则默认改变所有技能的历史次数
---@param num? integer @ 次数 默认0
---@param scope? integer @ 查询历史范围，若你填了num则必须填具体时机
function Player:setSkillUseHistory(skill_name, num, scope)
  skill_name = skill_name or ""

  if num == nil and scope == nil then
    if skill_name ~= "" then
      self.skillUsedHistory[skill_name] = {0, 0, 0, 0}
      self:setSkillBranchUseHistory(skill_name)
    else
      self.skillUsedHistory = {}
      self:setSkillBranchUseHistory()
    end
    return
  end

  num = num or 0
  assert(scope)
  if skill_name == "" then
    for _, v in pairs(self.skillUsedHistory) do
      v[scope] = num
    end
    return
  end

  if Fk.skill_skels[skill_name] then
    local main_name = string.format("#%s_main_skill", skill_name)
    self.skillUsedHistory[main_name] = self.skillUsedHistory[main_name] or {0, 0, 0, 0}
    self.skillUsedHistory[main_name][scope] = num
  end
  self.skillUsedHistory[skill_name] = self.skillUsedHistory[skill_name] or {0, 0, 0, 0}
  self.skillUsedHistory[skill_name][scope] = num
end

--- 设定玩家使用特定技能（skill skeleton）分支的历史次数。
--- `num`和`scope`均不写则为清空特定区域的历史次数
---@param skill_name? string @ 技能（skill skeleton）名，不写（或写空字符串）则默认改变**所有技能**之所有分支的历史次数
---@param branch? string @ 技能分支名，不写（或写空字符串）则默认改变某技能**所有分支**的历史次数
---@param num? integer @ 次数 默认0
---@param scope? integer @ 查询历史范围，若你填了num则必须填具体时机
function Player:setSkillBranchUseHistory(skill_name, branch, num, scope)
  skill_name = skill_name or ""
  branch = branch or ""
  if num == nil and scope == nil then
    if skill_name ~= "" then
      if branch ~= "" then
        self.skillBranchUsedHistory[skill_name][branch] = {0, 0, 0, 0}
      else
        self.skillBranchUsedHistory[skill_name] = {}
      end
    else
      self.skillBranchUsedHistory = {}
    end
    return
  end

  num = num or 0
  assert(scope)
  if skill_name == "" then
    for _, v in pairs(self.skillBranchUsedHistory) do
      if branch ~= "" then
        v[branch] = v[branch] or {0, 0, 0, 0}
        v[branch][scope] = num
      else
        for _, history in pairs(v) do
          history[scope] = num
        end
      end
    end
  else
    self.skillBranchUsedHistory[skill_name] = self.skillBranchUsedHistory[skill_name] or {}
    if branch ~= "" then
      self.skillBranchUsedHistory[skill_name][branch] = self.skillBranchUsedHistory[skill_name][branch] or {0, 0, 0, 0}
      self.skillBranchUsedHistory[skill_name][branch][scope] = num
    else
      for _, history in pairs(self.skillBranchUsedHistory[skill_name]) do
        history[scope] = num
      end
    end
  end
end

--- 清空玩家使用特定技能的历史次数
---@param skill_name string @ 技能名，若为主技能则同时清空所有技能效果和分支的历史次数
---@param scope? integer @ 清空的历史范围，不填则全部清空
function Player:clearSkillHistory(skill_name, scope)
  local skill = Fk.skills[skill_name]

  if skill then
    local skel = skill:getSkeleton()
    if skel.name == skill_name then
      if scope then
        for _, effect in ipairs(skel.effect_names) do
          self:setSkillUseHistory(effect, 0, scope)
        end
      else
        for _, effect in ipairs(skel.effect_names) do
          self:setSkillUseHistory(effect)
        end
      end
    end
  end

  if scope then
    self:setSkillUseHistory(skill_name, 0, scope)
  else
    self:setSkillUseHistory(skill_name)
  end
end

--- 获取玩家使用特定牌的历史次数（只算计入次数的部分）。
---@param cardName string @ 牌名
---@param scope? integer @ 查询历史范围，默认Turn
function Player:usedCardTimes(cardName, scope)
  if not self.cardUsedHistory[cardName] then
    return 0
  end
  scope = scope or Player.HistoryTurn
  return self.cardUsedHistory[cardName][scope]
end

--- 获取玩家使用特定技能的历史次数。
---@param skill_name string @ 技能(skill skeleton)名
---@param scope? integer @ 查询历史范围，默认Turn
---@param branch? string @ 不查询主技能使用次数，改为查询分支所属的次数限制
function Player:usedSkillTimes(skill_name, scope, branch)
  if not self.skillUsedHistory[skill_name] then
    return 0
  end
  scope = scope or Player.HistoryTurn

  if branch then
    if not self.skillBranchUsedHistory[skill_name] or not self.skillBranchUsedHistory[skill_name][branch] then
      return 0
    end

    return self.skillBranchUsedHistory[skill_name][branch][scope]
  end
  return self.skillUsedHistory[skill_name][scope]
end

--- 获取玩家使用特定技能效果的历史次数。
---@param skill_name string @ 效果(skill effect)名
---@param scope? integer @ 查询历史范围，默认Turn
function Player:usedEffectTimes(skill_name, scope)
  if not self.skillUsedHistory[skill_name] then
    return 0
  end
  scope = scope or Player.HistoryTurn
  local skill = Fk.skills[skill_name]
  if not skill then
    return self.skillUsedHistory[skill_name][scope]
  end

  local skel = skill:getSkeleton()
  if skel then
    if skel.name ~= skill_name then
      return self.skillUsedHistory[skill_name][scope]
    else
      local main_name = string.format("#%s_main_skill", skill_name)
      if not self.skillUsedHistory[main_name] then
        return 0
      end
      return self.skillUsedHistory[main_name][scope]
    end
  end
  return self.skillUsedHistory[skill_name][scope]
end

function Player:isAlive()
  return self.dead == false
end

--- 获取玩家是否无手牌。
---@return boolean
function Player:isKongcheng()
  return #self:getCardIds(Player.Hand) == 0
end

--- 获取玩家是否没有牌（即无手牌及装备区牌）。
---@return boolean
function Player:isNude()
  return #self:getCardIds{Player.Hand, Player.Equip} == 0
end

--- 获取玩家所有区域是否无牌。
---@return boolean
function Player:isAllNude()
  return #self:getCardIds() == 0
end

--- 获取玩家是否受伤。
---@return boolean
function Player:isWounded()
  return self.hp < self.maxHp
end

--- 获取玩家已失去体力。
---@return integer
function Player:getLostHp()
  return math.min(self.maxHp - self.hp, self.maxHp)
end

---@param skill string | Skill
---@return Skill
local function getActualSkill(skill)
  if type(skill) == "string" then
    skill = Fk.skills[skill]
  end
  assert(skill:isInstanceOf(Skill))
  return skill
end

--- 检索玩家是否有对应技能。
---@param skill string | Skill @ 技能名
---@param ignoreNullified? boolean @ 忽略技能是否被无效
---@param ignoreAlive? boolean @ 忽略角色在场与否
---@return boolean
function Player:hasSkill(skill, ignoreNullified, ignoreAlive)
  if not ignoreAlive and self.dead then
    return false
  end

  if type(skill) == "string" then
    skill = Fk.skills[skill]
    if skill == nil then return false end
  end
  local skel = skill:getSkeleton()
  local effect = skill
  if skel then
    skill = Fk.skills[skel.name]
  end

  if not (ignoreNullified or skill:isEffectable(self)) then
    return false
  end

  if self:isInstanceOf(ServerPlayer) and ---@cast self ServerPlayer
    self:isFakeSkill(skill) and
    table.contains(self.prelighted_skills, skill) then -- 预亮的技能

    return not effect:isInstanceOf(StatusSkill) -- 预亮技能的effect状态技为false
  end

  if table.contains(self.player_skills, skill) then -- shownSkill
    if not effect:isInstanceOf(StatusSkill) then return true
    else
      return not self:isFakeSkill(skill)
    end
  else
    for _, skills in pairs(self.derivative_skills) do
      if table.contains(skills, skill) then return true end
    end
  end

  return false
end

--- 技能是否亮出
---@param skill string | Skill
---@return boolean
function Player:hasShownSkill(skill, ignoreNullified, ignoreAlive)
  if not self:hasSkill(skill, ignoreNullified, ignoreAlive) then return false end

  if self:isInstanceOf(ServerPlayer) then ---@cast self ServerPlayer
    return not self:isFakeSkill(skill)
  else
    if type(skill) == "string" then skill = Fk.skills[skill] end
    for _, skills in pairs(self.derivative_skills) do
      if table.contains(skills, skill) then return true end
    end
    return table.contains(self.player_skills, skill)
  end
end

--- 为玩家增加对应技能。
---@param skill string | Skill @ 技能名
---@param source_skill? string | Skill @ 本有技能（和衍生技能相对）
---@return Skill[] @ got skills that Player didn't have at start
function Player:addSkill(skill, source_skill)
  skill = getActualSkill(skill)

  local toget = {table.unpack(skill.related_skills)}
  table.insert(toget, skill)

  local room = Fk:currentRoom()
  local ret = {}
  for _, s in ipairs(toget) do
    if not self:hasSkill(s, true, true) then
      table.insert(ret, s)
      if (s:isInstanceOf(TriggerSkill) --[[or s:isInstanceOf(LegacyTriggerSkill)]]) and RoomInstance then
        ---@cast room Room
        ---@cast s TriggerSkill --|LegacyTriggerSkill
        room.logic:addTriggerSkill(s)
      end
      if s:isInstanceOf(StatusSkill) then
        room.status_skills[s.class] = room.status_skills[s.class] or {}
        table.insertIfNeed(room.status_skills[s.class], s)
      end
    end
  end

  if source_skill then
    source_skill = getActualSkill(source_skill)
    if not self.derivative_skills[source_skill] then
      self.derivative_skills[source_skill] = {}
    end
    table.insertIfNeed(self.derivative_skills[source_skill], skill)
  else
    table.insertIfNeed(self.player_skills, skill)
  end

  -- add related skills
  if not self.derivative_skills[skill] then
    self.derivative_skills[skill] = {}
  end
  for _, s in ipairs(skill.related_skills) do
    table.insertIfNeed(self.derivative_skills[skill], s)
  end

  return ret
end

--- 为玩家删除对应技能。
---@param skill string | Skill @ 技能名
---@param source_skill? string | Skill @ 本有技能（和衍生技能相对）
---@return Skill[] @ lost skills that the Player doesn't have anymore
function Player:loseSkill(skill, source_skill)
  skill = getActualSkill(skill)

  if source_skill then
    source_skill = getActualSkill(source_skill)
    if not self.derivative_skills[source_skill] then
      self.derivative_skills[source_skill] = {}
    end
    table.removeOne(self.derivative_skills[source_skill], skill)
    if #self.derivative_skills[source_skill] == 0 then
      self.derivative_skills[source_skill] = nil
    end
  else
    table.removeOne(self.player_skills, skill)
  end

  -- clear derivative skills of this skill as well
  local tolose = self.derivative_skills[skill] or {}
  table.insert(tolose, skill)
  self.derivative_skills[skill] = nil

  local ret = {}  ---@type Skill[]
  for _, s in ipairs(tolose) do
    if not self:hasSkill(s, true, true) then
      table.insert(ret, s)
    end
  end
  return ret
end

-- Hegemony func

---@param skill Skill | string
---@return Skill?
function Player:addFakeSkill(skill)
  assert(type(skill) == "string" or skill:isInstanceOf(Skill))
  if type(skill) == "string" then
    skill = Fk.skills[skill]
    assert(skill, "Skill not found")
  end
  if table.contains(self._fake_skills, skill) then return end

  table.insert(self._fake_skills, skill)
  for _, s in ipairs(skill.related_skills) do
    table.insert(self._fake_skills, s)
  end
  return skill
end

---@param skill Skill | string
---@return Skill?
function Player:loseFakeSkill(skill)
  assert(type(skill) == "string" or skill:isInstanceOf(Skill))
  if type(skill) == "string" then
    skill = Fk.skills[skill]
  end
  if not table.contains(self._fake_skills, skill) then return end

  table.removeOne(self._fake_skills, skill)
  for _, s in ipairs(skill.related_skills) do
    table.removeOne(self._fake_skills, s)
  end
  return skill
end

---@param skill Skill | string
function Player:isFakeSkill(skill)
  if type(skill) == "string" then skill = Fk.skills[skill] end
  assert(skill:isInstanceOf(Skill))
  return table.contains(self._fake_skills, skill)
end

--- 获取对应玩家所有技能。
-- return all skills that xxx:hasSkill() == true
---@return Skill[]
function Player:getAllSkills()
  local ret = {table.unpack(self.player_skills)}
  for _, skills in pairs(self.derivative_skills) do
    table.insertTableIfNeed(ret, skills)
  end
  return ret
end

--- 确认玩家是否可以使用特定牌。
---@param card Card @ 特定牌
---@param extra_data? UseExtraData @ 额外数据
function Player:canUse(card, extra_data)
  return not self:prohibitUse(card) and not not card.skill:canUse(self, card, extra_data)
end

--- 确认玩家是否可以对特定玩家使用特定牌。
---@param card Card @ 特定牌
---@param to Player @ 特定玩家
---@param extra_data? UseExtraData @ 额外数据
function Player:canUseTo(card, to, extra_data)
  if self:prohibitUse(card) or self:isProhibited(to, card) then return false end
  local _extra = extra_data and table.simpleClone(extra_data) or {}
  _extra.fix_targets = {to.id}
  local can_use = self:canUse(card, _extra) -- for judging peach canUse correctly
  return can_use and Util.CardTargetFilter(card.skill, self, to, {}, card.subcards, card, _extra)
end

--- 确认玩家是否可以使用/打出特定牌，考虑Fk.currentResponsePattern。
---@param card Card @ 特定牌
---@param extra_data? UseExtraData @ 额外数据（为nil的情况取当前req的extra_data信息）
function Player:canUseOrResponseInCurrent(card, extra_data)
  if Fk.currentResponsePattern == nil then
    return self:canUse(card, extra_data)
  else
    if Exppattern:Parse(Fk.currentResponsePattern):match(card) then
      if ClientInstance then
        local handler = ClientInstance.current_request_handler
        if handler and handler.class.name == "ReqResponseCard" then
          return not self:prohibitResponse(card)
        else
          extra_data = extra_data or handler.extra_data
          return not self:prohibitUse(card) and
            ((card.is_passive and not (extra_data or {}).not_passive) or card.skill:canUse(self, card, extra_data))
        end
      end
      return true
    end
  end
  return false
end

--- 当前可用的牌名筛选。用于转化技的interaction里对泛转化牌名的合法性检测
---@param skill_name string @ 泛转化技的技能名
---@param card_names string[] @ 待判定的牌名列表
---@param subcards? integer[] @ 子卡（某些技能可以提前确定子卡，如奇策、妙弦）
---@param ban_cards? string[] @ 被排除的卡名
---@param extra_data? UseExtraData|table @ 用于使用的额外信息（为nil的情况取当前req的extra_data信息）
---@param vs_pattern? string @ 转化后的卡牌pattern
---@return string[] @ 返回牌名列表
function Player:getViewAsCardNames(skill_name, card_names, subcards, ban_cards, extra_data, vs_pattern)
  ban_cards = ban_cards or Util.DummyTable
  --extra_data = extra_data or Util.DummyTable
  return table.filter(card_names, function (name)
    local card = Fk:cloneCard(name)
    if subcards then
      card.skillName = skill_name
      card:addSubcards(subcards)
    else
      card:setVSPattern(skill_name, self, vs_pattern)
    end
    if table.contains(ban_cards, card.trueName) or table.contains(ban_cards, card.name) then return false end
    return self:canUseOrResponseInCurrent(card, extra_data)
  end)
end

--- 确认玩家是否被禁止对特定玩家使用特定牌。
---@param to Player @ 特定玩家
---@param card Card @ 特定牌
function Player:isProhibited(to, card)
  local r = Fk:currentRoom()

  if card.type == Card.TypeEquip and #to:getAvailableEquipSlots(card.sub_type) == 0 then
    return true
  end

  if card.sub_type == Card.SubtypeDelayedTrick and
      (table.contains(to.sealedSlots, Player.JudgeSlot) or to:hasDelayedTrick(card.name)) then
    return true
  end

  local status_skills = r.status_skills[ProhibitSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    if skill:isProhibited(self, to, card) then
      return true
    end
  end
  return false
end

--- 确认角色是否被禁止成为特定牌的目标（目前仅用于移动场上的延时锦囊）
---@param card Card @ 特定牌
function Player:isProhibitedTarget(card)
  local r = Fk:currentRoom()

  if card.type == Card.TypeEquip and #self:getAvailableEquipSlots(card.sub_type) == 0 then
    return true
  end

  if card.sub_type == Card.SubtypeDelayedTrick and
      (table.contains(self.sealedSlots, Player.JudgeSlot) or (self:hasDelayedTrick(card.name) and not card.stackable_delayed)) then
    return true
  end

  local status_skills = r.status_skills[ProhibitSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    if skill:isProhibited(nil, self, card) then
      return true
    end
  end
  return false
end


--- 确认玩家是否被禁止使用特定牌。
---@param card Card @ 特定的牌
function Player:prohibitUse(card)
  local status_skills = Fk:currentRoom().status_skills[ProhibitSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    if skill:prohibitUse(self, card) then
      return true
    end
  end
  return false
end

--- 确认玩家是否被禁止打出特定牌。
---@param card Card @ 特定的牌
function Player:prohibitResponse(card)
  local status_skills = Fk:currentRoom().status_skills[ProhibitSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    if skill:prohibitResponse(self, card) then
      return true
    end
  end
  return false
end

--- 确认玩家是否被禁止弃置特定牌。
---@param card Card|integer @ 特定的牌
function Player:prohibitDiscard(card)
  if type(card) == "number" then
    card = Fk:getCardById(card)
  end

  local status_skills = Fk:currentRoom().status_skills[ProhibitSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    if skill:prohibitDiscard(self, card) then
      return true
    end
  end
  return false
end

--- 确认角色是否被禁止亮将。
function Player:prohibitReveal(isDeputy)
  local place = isDeputy and "d" or "m"
  if type(self:getMark(MarkEnum.RevealProhibited)) == "table" and table.contains(self:getMark(MarkEnum.RevealProhibited), place) then
    return true
  end

  for mark, value in pairs(self.mark) do
    if mark:startsWith(MarkEnum.RevealProhibited .. "-") and type(value) == "table" then
      for _, suffix in ipairs(MarkEnum.TempMarkSuffix) do
        if mark:find(suffix, 1, true) then return true end
      end
    end
  end
  -- for _, m in ipairs(table.map(MarkEnum.TempMarkSuffix, function(s)
  --     return self:getMark(MarkEnum.RevealProhibited .. s)
  --   end)) do
  --   if type(m) == "table" and table.contains(m, place) then
  --     return true
  --   end
  -- end
  return false
end

--- 判断能否拼点
---@param to Player @ 拼点对象
---@param ignoreFromKong? boolean @ 忽略发起者没有手牌
---@param ignoreToKong? boolean @ 忽略对象没有手牌
---@return boolean
function Player:canPindian(to, ignoreFromKong, ignoreToKong)
  if self == to then return false end

  if self:isKongcheng() and not ignoreFromKong then
    return false
  end
  if to:isKongcheng() and not ignoreToKong then
    return false
  end
  local status_skills = Fk:currentRoom().status_skills[ProhibitSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    if skill:prohibitPindian(self, to) then
      return false
    end
  end
  return true
end

--- 判断一张牌能否移动至某角色的装备区
---@param cardId integer | Card @ 移动的牌
---@param convert? boolean @ 是否可以替换装备（默认可以）
---@return boolean
function Player:canMoveCardIntoEquip(cardId, convert)
  convert = (convert == nil) and true or convert
  local card = type(cardId) == "number" and Fk:getCardById(cardId) or cardId
  if self.dead then return false end

  if not (card.sub_type >= 3 and card.sub_type <= 7) then return false end
  if type(cardId) == "number" then
    if table.contains(self:getCardIds("e"), cardId) then return false end
  else
    if table.find(Card:getIdList(cardId), function (id)
      return table.contains(self:getCardIds("e"), id)
    end) then
      return false
    end
  end
  if self:hasEmptyEquipSlot(card.sub_type) or (#self:getEquipments(card.sub_type) > 0 and convert) then
    return true
  end
  return false
end

--- 角色当前拥有的技能(skel)名列表。只包含武将技能，不含装备技能、附加技能。包括模式技
---@return string[]
function Player:getSkillNameList()
  local names = {}
  for _, skill in ipairs(self.player_skills) do
    if not skill.name:startsWith("#") and not skill.name:endsWith("&") then
      local skel = skill:getSkeleton()
      if not skel.attached_equip then
        table.insertIfNeed(names, skel.name)
      end
    end
  end
  return names
end

--转换技状态阳
fk.SwitchYang = 0
--转换技状态阴
fk.SwitchYin = 1

--- 获取转换技状态
---@param skillName string @ 技能名
---@param afterUse? boolean @ 是否提前计算转换后状态
---@param inWord? boolean @ 是否返回文字
---@return number|string @ 转换技状态
function Player:getSwitchSkillState(skillName, afterUse, inWord)
  if afterUse then
    return self:getMark(MarkEnum.SwithSkillPreName .. skillName) < 1 and (inWord and "yin" or fk.SwitchYin) or (inWord and "yang" or fk.SwitchYang)
  else
    return self:getMark(MarkEnum.SwithSkillPreName .. skillName) < 1 and (inWord and "yang" or fk.SwitchYang) or (inWord and "yin" or fk.SwitchYin)
  end
end

--- 是否能移动特定牌至特定角色
---@param to Player @ 移动至的角色
---@param id integer @ 移动的牌
---@return boolean
function Player:canMoveCardInBoardTo(to, id)
  if self == to then
    return false
  end

  local card = self:getVirtualEquip(id) or Fk:getCardById(id)
  assert(card.type == Card.TypeEquip or card.sub_type == Card.SubtypeDelayedTrick)

  if card.type == Card.TypeEquip then
    return to:hasEmptyEquipSlot(card.sub_type)
  else
    return not to:isProhibitedTarget(card)
  end
end

--- 是否能移动特定区域牌至特定角色
--- @param to Player @ 移动至的角色
--- @param flag? string @ 移动的区域，`e`为装备区，`j`为判定区，`ej``nil`为装备区和判定区
--- @param excludeIds? integer[] @ 排除的牌
---@return boolean
function Player:canMoveCardsInBoardTo(to, flag, excludeIds)
  if self == to then
    return false
  end

  assert(flag == nil or table.contains({"e", "j", "ej", "je"}, flag))
  excludeIds = type(excludeIds) == "table" and excludeIds or {}

  local areas = {}
  if flag == "e" then
    table.insert(areas, Player.Equip)
  elseif flag == "j" then
    table.insert(areas, Player.Judge)
  else
    areas = { Player.Equip, Player.Judge }
  end

  for _, cardId in ipairs(self:getCardIds(areas)) do
    if not table.contains(excludeIds, cardId) and self:canMoveCardInBoardTo(to, cardId) then
      return true
    end
  end

  return false
end

--- 获取使命技状态
---@param skillName string
---@return string? @ 存在返回`failed` or `succeed`，不存在返回`nil`
function Player:getQuestSkillState(skillName)
  local questSkillState = self:getMark(MarkEnum.QuestSkillPreName .. skillName)
  return type(questSkillState) == "string" and questSkillState or nil
end


--- 获取角色未被废除的装备栏
---@param subtype? CardSubtype @ 指定的装备栏类型，不填则判断所有类型
---@return string[]
function Player:getAvailableEquipSlots(subtype)
  local tempSlots = table.simpleClone(self.equipSlots)
  local tempSealedSlots = table.simpleClone(self.sealedSlots)

  if subtype then
    local singleSlot = table.filter(tempSlots, function(slot)
      return slot == Util.convertSubtypeAndEquipSlot(subtype)
    end)

    for _, sealedSlot in ipairs(tempSealedSlots) do
      table.removeOne(singleSlot, sealedSlot)
    end

    return singleSlot
  end

  for _, sealedSlot in ipairs(tempSealedSlots) do
    table.removeOne(tempSlots, sealedSlot)
  end

  return tempSlots
end

--- 检索玩家是否有对应类型的空装备栏
---@param subtype? CardSubtype @ 指定的装备栏类型，不填则判断所有类型
---@return boolean
function Player:hasEmptyEquipSlot(subtype)
  return #self:getAvailableEquipSlots(subtype) - #self:getEquipments(subtype) > 0
end

function Player:addBuddy(other)
  table.insert(self.buddy_list, other.id)
end

function Player:removeBuddy(other)
  table.removeOne(self.buddy_list, other.id)
end

--- 是否为通牌队友
---@param other Player|integer
function Player:isBuddy(other)
  local room = Fk:currentRoom()
  if room.observing and not room.replaying then return false end
  local id = type(other) == "number" and other or other.id
  return self.id == id or table.contains(self.buddy_list, id)
end

--- Player是否可看到某card
--- @param cardId integer
---@param move? MoveCardsData @ 移动数据，注意涉及Player全是id
---@return boolean
function Player:cardVisible(cardId, move)
  local room = Fk:currentRoom()
  if room.replaying and room.replaying_show then return true end

  local function containArea(area, relevant, defaultVisible, specialName) --处理区的处理？
    if area == Card.PlayerSpecial then
      return relevant or (specialName and not specialName:startsWith("$"))
    end
    local areas = relevant
      and {Card.PlayerEquip, Card.PlayerJudge, Card.PlayerHand}
      or {Card.PlayerEquip, Card.PlayerJudge}
    return table.contains(areas, area) or (defaultVisible and table.contains({Card.Processing, Card.DiscardPile}, area))
  end

  local status_skills = Fk:currentRoom().status_skills[VisibilitySkill] or Util.DummyTable---@type VisibilitySkill[]

  local falsy = true -- 当难以决定时是否要选择暗置？
  local oldarea, oldspecial, oldowner
  if move then
    move = table.simpleClone(move)
    -- 把playerId转为Player
    if type(move.to) == "number" then move.to = room:getPlayerById(move.to) end
    if type(move.from) == "number" then move.from = room:getPlayerById(move.from) end
    ---@type MoveInfo
    local info = table.find(move.moveInfo, function(info) return info.cardId == cardId end)
    if info then
      for _, skill in ipairs(status_skills) do
        local f = skill:moveVisible(self, info, move)
        if f ~= nil then
          return f
        end
      end

      oldarea = info.fromArea
      oldspecial = info.fromSpecialName
      oldowner = move.from
      if move.moveVisible or move.specialVisible then return true end
      if move.visiblePlayers then
        local visiblePlayers = move.visiblePlayers
        if type(visiblePlayers) == "number" then
          if self:isBuddy(visiblePlayers) then
            return true
          end
        elseif type(visiblePlayers) == "table" then
          if table.find(visiblePlayers, function(pid) return self:isBuddy(pid) end) then
            return true
          end
        end
      end
      if containArea(info.fromArea, move.from and self:isBuddy(move.from), move.moveVisible == nil, oldspecial) then
        return true
      end
      if move.moveVisible ~= nil then falsy = false end
    end
  end

  local area = room:getCardArea(cardId)
  local owner = room:getCardOwner(cardId)
  local card = Fk:getCardById(cardId)

  if not room.observing then
    for _, skill in ipairs(status_skills) do
      local f = skill:cardVisible(self, card)
      if f ~= nil then
        return f
      end
    end
  end

  if containArea(area, owner and self:isBuddy(owner), falsy, owner and owner:getPileNameOfId(cardId)) then
    return true
  end

  return false
end

--- Player是否可看到某target的身份
--- @param target Player
---@return boolean
function Player:roleVisible(target)
  local room = Fk:currentRoom()
  local status_skills = room.status_skills[VisibilitySkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    local f = skill:roleVisible(self, target)
    if f ~= nil then
      return f
    end
  end

  if (room.replaying or not room.observing) and target == self then return true end
  if room.replaying and room.replaying_show then return true end

  return target.role_shown
end

--- 比较两名角色的性别是否相同。
---@param other Player @ 另一名角色
---@param diff boolean? @ 比较二者不同
---@return boolean @ 返回比较结果
function Player:compareGenderWith(other, diff)
  if self == other then return not diff end
  if self.gender == General.Agender or other.gender == General.Agender then return false end
  if self.gender == General.Bigender or other.gender == General.Bigender then return true end
  if diff then
    return self.gender ~= other.gender
  else
    return self.gender == other.gender
  end
end

--- 是否为男性（包括双性）。
function Player:isMale()
  return self.gender == General.Male or self.gender == General.Bigender
end

--- 是否为女性（包括双性）。
function Player:isFemale()
  return self.gender == General.Female or self.gender == General.Bigender
end

--- 是否为友方
---@param to Player @ 待判断的角色
---@return boolean
function Player:isFriend(to)
  return Fk.game_modes[Fk:currentRoom().settings.gameMode]:friendEnemyJudge(self, to)
end

--- 是否为敌方
---@param to Player @ 待判断的角色
---@return boolean
function Player:isEnemy(to)
  return not Fk.game_modes[Fk:currentRoom().settings.gameMode]:friendEnemyJudge(self, to)
end

--- 获得队友
---@param include_self? boolean @ 是否包括自己。默认是
---@param include_dead? boolean @ 是否包括死亡角色。默认否
---@return Player[]
function Player:getFriends(include_self, include_dead)
  if include_self == nil then include_self = true end
  local players = include_dead and Fk:currentRoom().players or Fk:currentRoom().alive_players
  local friends = table.filter(players, function (p)
    return self:isFriend(p)
  end)
  if not include_self then
    table.removeOne(friends, self)
  end
  return friends
end

--- 获得敌人
---@param include_dead? boolean @ 是否包括死亡角色。默认否
---@return Player[]
function Player:getEnemies(include_dead)
  local players = include_dead and Fk:currentRoom().players or Fk:currentRoom().alive_players
  local enemies = table.filter(players, function (p)
    return self:isEnemy(p)
  end)
  return enemies
end

--- 判断角色是否可以排序手牌
---@return boolean
function Player:canSortHandcards()
  for m, _ in pairs(self.mark) do
    if m == MarkEnum.SortProhibited or m:startsWith(MarkEnum.SortProhibited .. "-") then return false end
  end
  return true
end

--- 能否获得某技能（用于游戏开始时或变更武将时，主动技、势力技、主副将技等特殊限制技能的判断）
---@param skill Skill|string @ 待获取的技能
---@param relate_to_place? "m" | "d" @ 此技能属于主将或副将，不填则不做判断
---@return boolean
function Player:canAttachSkill(skill, relate_to_place)
  if type(skill) == "string" then
    skill = Fk.skills[skill]
    if skill == nil then return false end
  end
  -- 主公技的获取条件暂定为:身份为主公且可见，游戏模式为身份模式
  if skill:hasTag(Skill.Lord) and not (self.role == "lord" and self.role_shown and Fk:currentRoom():isGameMode("role_mode")) then
    return false
  end
  if skill:hasTag(Skill.AttachedKingdom) and not table.contains(skill:getSkeleton().attached_kingdom, self.kingdom) then
    return false
  end
  if skill:hasTag(skill.MainPlace) and relate_to_place and relate_to_place ~= "m"  then
    return false
  end
  if skill:hasTag(skill.DeputyPlace) and relate_to_place and relate_to_place ~= "d" then
    return false
  end
  return true
end

function Player:serialize()
  local o = basePlayer.serialize(self)

  o.card_history = self.cardUsedHistory
  o.skill_history = self.skillUsedHistory
  o.skills = table.map(self.player_skills, Util.NameMapper)
  o.player_cards = self.player_cards
  o.special_cards = self.special_cards
  o.buddy_list = self.buddy_list
  o.virtual_equips = self.virtual_equips

  return o
end

function Player:deserialize(o)
  basePlayer.deserialize(self, o)

  self.cardUsedHistory = o.card_history
  self.skillUsedHistory = o.skill_history
  for _, sname in ipairs(o.skills) do self:addSkill(sname) end
  self.player_cards = o.player_cards
  self.special_cards = o.special_cards
  self.buddy_list = o.buddy_list
  self.virtual_equips = o.virtual_equips

  local pid = self.id
  local room = Fk:currentRoom()
  for _, id in ipairs(o.player_cards[Player.Hand]) do
    room:setCardArea(id, Card.PlayerHand, pid)
  end
  for _, id in ipairs(o.player_cards[Player.Equip]) do
    room:setCardArea(id, Card.PlayerEquip, pid)
  end
  for _, id in ipairs(o.player_cards[Player.Judge]) do
    room:setCardArea(id, Card.PlayerJudge, pid)
  end
  for _, ids in pairs(o.special_cards) do
    for _, id in ipairs(ids) do
      room:setCardArea(id, Card.PlayerSpecial, pid)
    end
  end
end

return Player
