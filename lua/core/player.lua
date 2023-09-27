-- SPDX-License-Identifier: GPL-3.0-or-later

--- 玩家分为客户端要处理的玩家，以及服务端处理的玩家两种。
---
--- 客户端能知道的玩家的信息十分有限，而服务端知道一名玩家的所有细节。
---
--- Player类就是这两种玩家的基类，包含它们共用的部分。
---
---@class Player : Object
---@field public id integer @ 玩家的id，每名玩家的id是唯一的。机器人的id是负数。
---@field public hp integer @ 体力值
---@field public maxHp integer @ 体力上限
---@field public shield integer @ 护甲数
---@field public kingdom string @ 势力
---@field public role string @ 身份
---@field public general string @ 武将
---@field public deputyGeneral string @ 副将
---@field public gender integer @ 性别
---@field public seat integer @ 座位号
---@field public next Player @ 下家
---@field public phase Phase @ 当前阶段
---@field public faceup boolean @ 是否正面朝上
---@field public chained boolean @ 是否被横直
---@field public dying boolean @ 是否处于濒死
---@field public dead boolean @ 是否死亡
---@field public player_skills Skill[] @ 当前拥有的所有技能
---@field public derivative_skills table<Skill, Skill[]> @ 当前拥有的派生技能
---@field public flag string[] @ 当前拥有的flag，不过好像没用过
---@field public tag table<string, any> @ 当前拥有的所有tag，好像也没用过
---@field public mark table<string, integer> @ 当前拥有的所有标记，用烂了
---@field public player_cards table<integer, integer[]> @ 当前拥有的所有牌，键是区域，值是id列表
---@field public virtual_equips Card[] @ 当前的虚拟装备牌，其实也包含着虚拟延时锦囊这种
---@field public special_cards table<string, integer[]> @ 类似“屯田”这种的私人牌堆
---@field public cardUsedHistory table<string, integer[]> @ 用牌次数历史记录
---@field public skillUsedHistory table<string, integer[]> @ 发动技能次数的历史记录
---@field public fixedDistance table<Player, integer> @ 与其他玩家的固定距离列表
---@field public buddy_list integer[] @ 队友列表，或者说自己可以观看别人手牌的那些玩家的列表
local Player = class("Player")

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

--- 构造函数。总之这不是随便调用的函数
function Player:initialize()
  self.id = 0
  self.hp = 0
  self.maxHp = 0
  self.kingdom = "qun"
  self.role = ""
  self.general = ""
  self.deputyGeneral = ""
  self.gender = General.Male
  self.seat = 0
  self.next = nil
  self.phase = Player.NotActive
  self.faceup = true
  self.chained = false
  self.dying = false
  self.dead = false
  self.drank = 0

  self.player_skills = {}
  self.derivative_skills = {}
  self.flag = {}
  self.tag = {}
  self.mark = {}
  self.player_cards = {
    [Player.Hand] = {},
    [Player.Equip] = {},
    [Player.Judge] = {},
  }
  self.virtual_equips = {}
  self.special_cards = {}

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
  self.fixedDistance = {}
  self.buddy_list = {}
end

function Player:__tostring()
  return string.format("<%s %d>", self.id < 0 and "Bot" or "Player", math.abs(self.id))
end

--- 设置角色、体力、技能。
---@param general General @ 角色类型
---@param setHp bool @ 是否设置体力
---@param addSkills bool @ 是否增加技能
function Player:setGeneral(general, setHp, addSkills)
  self.general = general.name
  if setHp then
    self.maxHp = general.maxHp
    self.hp = general.hp
  end

  if addSkills then
    table.insertTable(self.player_skills, general.skills)
  end
end

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
function Player:hasFlag(flag)
  return table.contains(self.flag, flag)
end

--- 为角色赋予flag。
---@param flag string @ 一种标记
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

--- 为角色赋予Mark。
---@param mark string @ 标记
---@param count integer @ 为标记赋予的数量
-- mark name and UI:
-- 'xxx': invisible mark
-- '@mark': mark with extra data (maybe string or number)
-- '@@mark': mark without data
-- '@$mark': mark with card_name[] data
-- '@&mark': mark with general_name[] data
function Player:addMark(mark, count)
  count = count or 1
  local num = self.mark[mark]
  num = num or 0
  self:setMark(mark, math.max(num + count, 0))
end

--- 为角色移除Mark。
---@param mark string @ 标记
---@param count integer @ 为标记删除的数量
function Player:removeMark(mark, count)
  count = count or 1
  local num = self.mark[mark]
  num = num or 0
  self:setMark(mark, math.max(num - count, 0))
end

--- 为角色设置Mark至指定数量。
---@param mark string @ 标记
---@param count integer|nil @ 为标记删除的数量
function Player:setMark(mark, count)
  if count == 0 then count = nil end
  if self.mark[mark] ~= count then
    self.mark[mark] = count
  end
end

--- 获取角色对应Mark的数量。
---@param mark string @ 标记
---@return any
function Player:getMark(mark)
  return (self.mark[mark] or 0)
end

--- 判定角色是否拥有对应的Mark。
---@param mark string @ 标记
---@return boolean
function Player:hasMark(mark)
  fk.qWarning("hasMark will be deleted in future version!")
  return self:getMark(mark) ~= 0
end

--- 获取角色有哪些Mark。
function Player:getMarkNames()
  local ret = {}
  for k, _ in pairs(self.mark) do
    table.insert(ret, k)
  end
  return ret
end

--- 将指定数量的牌加入玩家的对应区域。
---@param playerArea PlayerCardArea @ 玩家牌所在的区域
---@param cardIds integer[] @ 牌的ID，返回唯一牌
---@param specialName string|nil @ 私人牌堆名
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
---@param specialName string|nil @ 私人牌堆名
function Player:removeCards(playerArea, cardIds, specialName)
  assert(table.contains({ Player.Hand, Player.Equip, Player.Judge, Player.Special }, playerArea))
  assert(playerArea ~= Player.Special or type(specialName) == "string")

  local fromAreaIds = playerArea == Player.Special and self.special_cards[specialName] or self.player_cards[playerArea]
  if fromAreaIds then
    for _, id in ipairs(cardIds) do
      if #fromAreaIds == 0 then
        break
      end

      if table.contains(fromAreaIds, id) then
        table.removeOne(fromAreaIds, id)
      -- FIXME: 为客户端移动id为-1的牌考虑，但总感觉有地方需要商讨啊！
      elseif table.every(fromAreaIds, function(e) return e == -1 end) then
        table.remove(fromAreaIds, 1)
      elseif id == -1 then
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
function Player:getVirualEquip(cid)
  for _, c in ipairs(self.virtual_equips) do
    for _, id in ipairs(c.subcards) do
      if id == cid then
        return c
      end
    end
  end
end

--- 确认玩家判定区是否存在延迟锦囊牌。
function Player:hasDelayedTrick(card_name)
  for _, id in ipairs(self:getCardIds(Player.Judge)) do
    local c = self:getVirualEquip(id)
    if not c then c = Fk:getCardById(id) end
    if c.name == card_name then
      return true
    end
  end
end

--- 获取玩家特定区域所有牌的ID。
---@param playerAreas PlayerCardArea|PlayerCardArea[]|string|nil @ 玩家牌所在的区域
---@param specialName string|nil @私人牌堆名
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

  local rightAreas = { Player.Hand, Player.Equip, Player.Judge, Player.Special }
  local cardIds = {}
  for _, area in ipairs(areas) do
    assert(table.contains(rightAreas, area))
    assert(area ~= Player.Special or type(specialName) == "string")
    local currentCardIds = area == Player.Special and self.special_cards[specialName] or self.player_cards[area]
    table.insertTable(cardIds, currentCardIds)
  end

  return cardIds
end

--- 通过名字检索获取玩家是否存在对应私人牌堆。
---@param name string @ 私人牌堆名
function Player:getPile(name)
  return self.special_cards[name] or {}
end

--- 通过ID检索获取玩家是否存在对应私人牌堆。
---@param id integer @ 私人牌堆ID
---@return string|null
function Player:getPileNameOfId(id)
  for k, v in pairs(self.special_cards) do
    if table.contains(v, id) then return k end
  end
end

--- 返回所有“如手牌般使用或打出”的牌。
--- 或者说，返回所有名字以“&”结尾的pile的牌。
---@param include_hand bool @ 是否包含真正的手牌
---@return integer[]
function Player:getHandlyIds(include_hand)
  local ret = include_hand and self:getCardIds("h") or {}
  for k, v in pairs(self.special_cards) do
    if k:endsWith("&") then table.insertTable(ret, v) end
  end
  return ret
end

-- for fkp only
function Player:getHandcardNum()
  return #self:getCardIds(Player.Hand)
end

function Player:filterHandcards()
  for _, id in ipairs(self:getCardIds(Player.Hand)) do
    Fk:filterCard(id, self)
  end
end

--- 检索玩家装备区是否存在对应类型的装备。
---@param cardSubtype CardSubtype @ 卡牌子类
---@return integer|null @ 返回卡牌ID或nil
function Player:getEquipment(cardSubtype)
  for _, cardId in ipairs(self.player_cards[Player.Equip]) do
    if Fk:getCardById(cardId).sub_type == cardSubtype then
      return cardId
    end
  end

  return nil
end

--- 检索玩家装备区是否存在对应类型的装备列表。
---@param cardSubtype CardSubtype @ 卡牌子类
---@return integer[] @ 返回卡牌ID或空表
function Player:getEquipments(cardSubtype)
  local cardIds = {}
  for _, cardId in ipairs(self.player_cards[Player.Equip]) do
    if Fk:getCardById(cardId).sub_type == cardSubtype then
      table.insert(cardIds, cardId)
    end
  end

  return cardIds
end

--- 获取玩家手牌上限。
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

--- 获取玩家攻击距离。
function Player:getAttackRange()
  local weapon = Fk:getCardById(self:getEquipment(Card.SubtypeWeapon))
  local baseAttackRange = math.max(weapon and weapon.attack_range or 1, 0)

  local status_skills = Fk:currentRoom().status_skills[AttackRangeSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    local correct = skill:getCorrect(self)
    baseAttackRange = baseAttackRange + (correct or 0)
  end

  return math.max(baseAttackRange, 0)
end

--- 获取角色是否被移除。
function Player:isRemoved()
  return self:getMark(MarkEnum.PlayerRemoved) ~= 0 or table.find(MarkEnum.TempMarkSuffix, function(s)
    return self:getMark(MarkEnum.PlayerRemoved .. s) ~= 0
  end)
end

--- 修改玩家与其他角色的固定距离。
---@param other Player @ 其他玩家
---@param num integer @ 距离数
function Player:setFixedDistance(other, num)
  --print(self.name .. ": fixedDistance is deprecated. Use fixed_func instead.")
  self.fixedDistance[other] = num
end

--- 移除玩家与其他角色的固定距离。
---@param other Player @ 其他玩家
function Player:removeFixedDistance(other)
  --print(self.name .. ": fixedDistance is deprecated. Use fixed_func instead.")
  self.fixedDistance[other] = nil
end

--- 获取玩家与其他角色的实际距离。
---
--- 通过 二者位次+距离技能之和 与 两者间固定距离 进行对比，更大的为实际距离。
---@param other Player @ 其他玩家
---@param mode string|nil @ 计算模式(left/right/both)
---@param ignore_dead bool @ 是否忽略尸体
function Player:distanceTo(other, mode, ignore_dead)
  assert(other:isInstanceOf(Player))
  mode = mode or "both"
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

  local status_skills = Fk:currentRoom().status_skills[DistanceSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    local fixed = skill:getFixed(self, other)
    local correct = skill:getCorrect(self, other)
    if fixed ~= nil then
      ret = fixed
      break
    end
    ret = ret + (correct or 0)
  end

  if self.fixedDistance[other] then
    ret = self.fixedDistance[other]
  end

  return math.max(ret, 1)
end

--- 获取其他玩家是否在玩家的攻击距离内。
---@param other Player @ 其他玩家
---@param fixLimit number|null @ 卡牌距离限制增加专用
function Player:inMyAttackRange(other, fixLimit)
  assert(other:isInstanceOf(Player))
  if self == other or (other and (other.dead or other:isRemoved())) or self:isRemoved() then
    return false
  end

  fixLimit = fixLimit or 0

  local status_skills = Fk:currentRoom().status_skills[AttackRangeSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    if skill:withinAttackRange(self, other) then
      return true
    end
  end

  local baseAttackRange = self:getAttackRange()
  return self:distanceTo(other) <= (baseAttackRange + fixLimit)
end

--- 获取下家。
---@param ignoreRemoved bool @ 忽略被移除
---@return ServerPlayer
function Player:getNextAlive(ignoreRemoved)
  if #Fk:currentRoom().alive_players == 0 then
    return self
  end
  local doNotIgnore = not ignoreRemoved
  if doNotIgnore and table.every(Fk:currentRoom().alive_players, function(p) return p:isRemoved() end) then
    return self
  end

  local ret = self.next
  while ret.dead or (doNotIgnore and ret:isRemoved()) do
    ret = ret.next
  end
  return ret
end

--- 增加玩家使用特定牌的历史次数。
---@param cardName string @ 牌名
---@param num integer|nil @ 次数
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
---@param num integer @ 次数
---@param scope integer|nil @ 查询历史范围
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
---@param num integer|nil @ 次数
function Player:addSkillUseHistory(skill_name, num)
  num = num or 1
  assert(type(num) == "number" and num ~= 0)

  self.skillUsedHistory[skill_name] = self.skillUsedHistory[skill_name] or {0, 0, 0, 0}
  local t = self.skillUsedHistory[skill_name]
  for i, _ in ipairs(t) do
    t[i] = t[i] + num
  end
end

--- 设定玩家使用特定技能的历史次数。
---@param skill_name string @ 技能名
---@param num integer|nil @ 次数
---@param scope integer|nil @ 查询历史范围
function Player:setSkillUseHistory(skill_name, num, scope)
  if skill_name == "" and num == nil and scope == nil then
    self.skillUsedHistory = {}
    return
  end

  num = num or 0
  if skill_name == "" then
    for _, v in pairs(self.skillUsedHistory) do
      v[scope] = num
    end
    return
  end

  self.skillUsedHistory[skill_name] = self.skillUsedHistory[skill_name] or {0, 0, 0, 0}
  self.skillUsedHistory[skill_name][scope] = num
end

--- 获取玩家使用特定牌的历史次数。
---@param cardName string @ 牌名
---@param scope integer|nil @ 查询历史范围
function Player:usedCardTimes(cardName, scope)
  if not self.cardUsedHistory[cardName] then
    return 0
  end
  scope = scope or Player.HistoryTurn
  return self.cardUsedHistory[cardName][scope]
end

--- 获取玩家使用特定技能的历史次数。
---@param skill_name string @ 技能名
---@param scope integer|nil @ 查询历史范围
function Player:usedSkillTimes(skill_name, scope)
  if not self.skillUsedHistory[skill_name] then
    return 0
  end
  scope = scope or Player.HistoryTurn
  return self.skillUsedHistory[skill_name][scope]
end

--- 获取玩家是否无手牌。
function Player:isKongcheng()
  return #self:getCardIds(Player.Hand) == 0
end

--- 获取玩家是否无手牌及装备牌。
function Player:isNude()
  return #self:getCardIds{Player.Hand, Player.Equip} == 0
end

--- 获取玩家所有区域是否无牌。
function Player:isAllNude()
  return #self:getCardIds() == 0
end

--- 获取玩家是否受伤。
function Player:isWounded()
  return self.hp < self.maxHp
end

--- 获取玩家已失去体力。
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
---@param ignoreNullified bool @ 忽略技能是否被无效
---@param ignoreAlive bool @ 忽略角色在场与否
function Player:hasSkill(skill, ignoreNullified, ignoreAlive)
  if not ignoreAlive and self.dead then
    return false
  end

  skill = getActualSkill(skill)

  if not (ignoreNullified or skill:isEffectable(self)) then
    return false
  end

  if table.contains(self.player_skills, skill) then
    return true
  end

  if self:isInstanceOf(ServerPlayer) and -- isInstanceOf(nil) will return false
    table.contains(self._fake_skills, skill) and
    table.contains(self.prelighted_skills, skill) then

    return true
  end

  for _, v in pairs(self.derivative_skills) do
    if table.contains(v, skill) then
      return true
    end
  end

  return false
end

--- 为玩家增加对应技能。
---@param skill string | Skill @ 技能名
---@param source_skill string | Skill | nil @ 本有技能（和衍生技能相对）
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
      if s:isInstanceOf(TriggerSkill) and RoomInstance then
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
---@param source_skill string | Skill | nil @ 本有技能（和衍生技能相对）
---@return Skill[] @ lost skills that the Player doesn't have anymore
function Player:loseSkill(skill, source_skill)
  skill = getActualSkill(skill)

  if source_skill then
    source_skill = getActualSkill(source_skill)
    if not self.derivative_skills[source_skill] then
      self.derivative_skills[source_skill] = {}
    end
    table.removeOne(self.derivative_skills[source_skill], skill)
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

--- 获取对应玩家所有技能。
-- return all skills that xxx:hasSkill() == true
function Player:getAllSkills()
  local ret = {table.unpack(self.player_skills)}
  for _, t in pairs(self.derivative_skills) do
    for _, s in ipairs(t) do
      table.insertIfNeed(ret, s)
    end
  end
  return ret
end

--- 确认玩家是否可以使用特定牌。
---@param card Card @ 特定牌
function Player:canUse(card)
  assert(card, "Error: No Card")
  return card.skill:canUse(self, card)
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
---@param card Card @ 特定的牌
function Player:prohibitDiscard(card)
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
  for _, m in ipairs(table.map(MarkEnum.TempMarkSuffix, function(s)
      return self:getMark(MarkEnum.RevealProhibited .. s)
    end)) do
    if type(m) == "table" and table.contains(m, place) then
      return true
    end
  end
  return false
end

--转换技状态阳
fk.SwitchYang = 0
--转换技状态阴
fk.SwitchYin = 1

--- 获取转换技状态
---@param skillName string @ 技能名
---@param afterUse bool @ 是否提前计算转换后状态
---@param inWord bool @ 是否返回文字
---@return number|string @ 转换技状态
function Player:getSwitchSkillState(skillName, afterUse, inWord)
  if afterUse then
    return self:getMark(MarkEnum.SwithSkillPreName .. skillName) < 1 and (inWord and "yin" or fk.SwitchYin) or (inWord and "yang" or fk.SwitchYang)
  else
    return self:getMark(MarkEnum.SwithSkillPreName .. skillName) < 1 and (inWord and "yang" or fk.SwitchYang) or (inWord and "yin" or fk.SwitchYin)
  end
end

function Player:canMoveCardInBoardTo(to, id)
  if self == to then
    return false
  end

  local card = self:getVirualEquip(id) or Fk:getCardById(id)
  assert(card.type == Card.TypeEquip or card.sub_type == Card.SubtypeDelayedTrick)

  if card.type == Card.TypeEquip then
    return to:hasEmptyEquipSlot(card.sub_type)
  else
    return
      not (
        table.find(to:getCardIds(Player.Judge), function(cardId)
          return Fk:getCardById(cardId).name == card.name
        end) or
        table.contains(to.sealedSlots, Player.JudgeSlot)
      )
  end
end

function Player:canMoveCardsInBoardTo(to, flag, excludeIds)
  if self == to then
    return false
  end

  assert(flag == nil or flag == "e" or flag == "j")
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

function Player:getQuestSkillState(skillName)
  local questSkillState = self:getMark(MarkEnum.QuestSkillPreName .. skillName)
  return type(questSkillState) == "string" and questSkillState or nil
end

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

function Player:hasEmptyEquipSlot(subtype)
  return #self:getAvailableEquipSlots(subtype) - #self:getEquipments(subtype) > 0
end

function Player:addBuddy(other)
  table.insert(self.buddy_list, other.id)
end

function Player:removeBuddy(other)
  table.removeOne(self.buddy_list, other.id)
end

function Player:isBuddy(other)
  local id = type(other) == "number" and other or other.id
  return self.id == id or table.contains(self.buddy_list, id)
end

return Player
