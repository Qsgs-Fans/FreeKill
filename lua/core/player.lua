---@class Player : Object
---@field id integer
---@field hp integer
---@field maxHp integer
---@field kingdom string
---@field role string
---@field general string
---@field gender integer
---@field handcard_num integer
---@field seat integer
---@field next Player
---@field phase Phase
---@field faceup boolean
---@field chained boolean
---@field dying boolean
---@field dead boolean
---@field state string
---@field player_skills Skill[]
---@field derivative_skills table<Skill, Skill[]>
---@field flag string[]
---@field tag table<string, any>
---@field mark table<string, integer>
---@field player_cards table<integer, integer[]>
---@field virtual_equips Card[]
---@field special_cards table<string, integer[]>
---@field cardUsedHistory table<string, integer[]>
---@field skillUsedHistory table<string, integer[]>
---@field fixedDistance table<Player, integer>
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

function Player:initialize()
  self.id = 114514
  self.hp = 0
  self.maxHp = 0
  self.kingdom = "qun"
  self.role = ""
  self.general = ""
  self.gender = General.Male
  self.seat = 0
  self.next = nil
  self.phase = Player.NotActive
  self.faceup = true
  self.chained = false
  self.dying = false
  self.dead = false
  self.state = ""
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

  self.cardUsedHistory = {}
  self.skillUsedHistory = {}
  self.fixedDistance = {}
end

---@param general General
---@param setHp boolean
---@param addSkills boolean
function Player:setGeneral(general, setHp, addSkills)
  self.general = general
  if setHp then
    self.maxHp = general.maxHp
    self.hp = general.hp
  end

  if addSkills then
    table.insertTable(self.player_skills, general.skills)
  end
end

---@param flag string
function Player:hasFlag(flag)
  return table.contains(self.flag, flag)
end

---@param flag string
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

function Player:clearFlags()
  self.flag = {}
end

-- mark name and UI:
-- 'xxx': invisible mark
-- '@mark': mark with extra data (maybe string or number)
-- '@@mark': mark without data
function Player:addMark(mark, count)
  count = count or 1
  local num = self.mark[mark]
  num = num or 0
  self:setMark(mark, math.max(num + count, 0))
end

function Player:removeMark(mark, count)
  count = count or 1
  local num = self.mark[mark]
  num = num or 0
  self:setMark(mark, math.max(num - count, 0))
end

function Player:setMark(mark, count)
  if self.mark[mark] ~= count then
    self.mark[mark] = count
  end
end

function Player:getMark(mark)
  return (self.mark[mark] or 0)
end

function Player:getMarkNames()
  local ret = {}
  for k, _ in pairs(self.mark) do
    table.insert(ret, k)
  end
  return ret
end

---@param playerArea PlayerCardArea
---@param cardIds integer[]
---@param specialName string
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

---@param playerArea PlayerCardArea
---@param cardIds integer[]
---@param specialName string
function Player:removeCards(playerArea, cardIds, specialName)
  assert(table.contains({ Player.Hand, Player.Equip, Player.Judge, Player.Special }, playerArea))
  assert(playerArea ~= Player.Special or type(specialName) == "string")

  local fromAreaIds = playerArea == Player.Special and self.special_cards[specialName] or self.player_cards[playerArea]
  if fromAreaIds then
    for _, id in ipairs(cardIds) do
      if #fromAreaIds == 0 then
        break
      end

      table.removeOne(fromAreaIds, id)
    end
  end
end

-- virtual delayed trick can use these functions too

---@param card Card
function Player:addVirtualEquip(card)
  assert(card and card:isInstanceOf(Card) and card:isVirtual())
  table.insertIfNeed(self.virtual_equips, card)
end

---@param cid integer
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

---@param cid integer
function Player:getVirualEquip(cid)
  for _, c in ipairs(self.virtual_equips) do
    for _, id in ipairs(c.subcards) do
      if id == cid then
        return c
      end
    end
  end
end

function Player:hasDelayedTrick(card_name)
  for _, id in ipairs(self:getCardIds(Player.Judge)) do
    local c = self:getVirualEquip(id)
    if not c then c = Fk:getCardById(id) end
    if c.name == card_name then
      return true
    end
  end
end

---@param playerAreas PlayerCardArea
---@param specialName string
---@return integer[]
function Player:getCardIds(playerAreas, specialName)
  local rightAreas = { Player.Hand, Player.Equip, Player.Judge }
  playerAreas = playerAreas or rightAreas
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

---@param name string
function Player:getPile(name)
  return self.special_cards[name] or {}
end

---@param id integer
---@return string|null
function Player:getPileNameOfId(id)
  for k, v in pairs(self.special_cards) do
    if table.contains(v, id) then return k end
  end
end

-- for fkp only
function Player:getHandcardNum()
  return #self:getCardIds(Player.Hand)
end

---@param cardSubtype CardSubtype
---@return integer|null
function Player:getEquipment(cardSubtype)
  for _, cardId in ipairs(self.player_cards[Player.Equip]) do
    if Fk:getCardById(cardId).sub_type == cardSubtype then
      return cardId
    end
  end

  return nil
end

function Player:getMaxCards()
  local baseValue = math.max(self.hp, 0)

  local status_skills = Fk:currentRoom().status_skills[MaxCardsSkill] or {}
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
    baseValue = baseValue + c
  end

  return math.max(baseValue, 0)
end

function Player:getAttackRange()
  local weapon = Fk:getCardById(self:getEquipment(Card.SubtypeWeapon))
  local baseAttackRange = math.max(weapon and weapon.attack_range or 1, 0)

  return math.max(baseAttackRange, 0)
end

---@param other Player
---@param num integer
function Player:setFixedDistance(other, num)
  self.fixedDistance[other] = num
end

---@param other Player
function Player:removeFixedDistance(other)
  self.fixedDistance[other] = nil
end

---@param other Player
function Player:distanceTo(other)
  assert(other:isInstanceOf(Player))
  local right = 0
  local temp = self
  while temp ~= other do
    if not temp.dead then
      right = right + 1
    end
    temp = temp.next
  end
  local left = #Fk:currentRoom().alive_players - right
  local ret = math.min(left, right)

  local status_skills = Fk:currentRoom().status_skills[DistanceSkill] or {}
  for _, skill in ipairs(status_skills) do
    local correct = skill:getCorrect(self, other)
    if correct == nil then correct = 0 end
    ret = ret + correct
  end

  if self.fixedDistance[other] then
    ret = self.fixedDistance[other]
  end

  return math.max(ret, 1)
end

---@param other Player
function Player:inMyAttackRange(other)
  if self == other then
    return false
  end
  local baseAttackRange = self:getAttackRange()
  local status_skills = Fk:currentRoom().status_skills[AttackRangeSkill] or {}
  for _, skill in ipairs(status_skills) do
    local correct = skill:getCorrect(self, other)
    baseAttackRange = baseAttackRange + correct
  end
  return self:distanceTo(other) <= baseAttackRange
end

function Player:addCardUseHistory(cardName, num)
  num = num or 1
  assert(type(num) == "number" and num ~= 0)

  self.cardUsedHistory[cardName] = self.cardUsedHistory[cardName] or {0, 0, 0, 0}
  local t = self.cardUsedHistory[cardName]
  for i, _ in ipairs(t) do
    t[i] = t[i] + num
  end
end

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

function Player:addSkillUseHistory(skill_name, num)
  num = num or 1
  assert(type(num) == "number" and num ~= 0)

  self.skillUsedHistory[skill_name] = self.skillUsedHistory[skill_name] or {0, 0, 0, 0}
  local t = self.skillUsedHistory[skill_name]
  for i, _ in ipairs(t) do
    t[i] = t[i] + num
  end
end

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

  if self.skillUsedHistory[skill_name] then
    self.skillUsedHistory[skill_name][scope] = num
  end
end

function Player:usedCardTimes(cardName, scope)
  if not self.cardUsedHistory[cardName] then
    return 0
  end
  scope = scope or Player.HistoryTurn
  return self.cardUsedHistory[cardName][scope]
end

function Player:usedSkillTimes(cardName, scope)
  if not self.skillUsedHistory[cardName] then
    return 0
  end
  scope = scope or Player.HistoryTurn
  return self.skillUsedHistory[cardName][scope]
end

function Player:isKongcheng()
  return #self:getCardIds(Player.Hand) == 0
end

function Player:isNude()
  return #self:getCardIds{Player.Hand, Player.Equip} == 0
end

function Player:isAllNude()
  return #self:getCardIds() == 0
end

function Player:isWounded()
  return self.hp < self.maxHp
end

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

---@param skill string | Skill
function Player:hasSkill(skill)
  skill = getActualSkill(skill)

  if table.contains(self.player_skills, skill) then
    return true
  end

  for _, v in pairs(self.derivative_skills) do
    if table.contains(v, skill) then
      return true
    end
  end

  return false
end

---@param skill string | Skill
---@param source_skill string | Skill | nil
---@return Skill[] @ got skills that Player didn't have at start
function Player:addSkill(skill, source_skill)
  skill = getActualSkill(skill)

  local toget = {table.unpack(skill.related_skills)}
  table.insert(toget, skill)

  local room = Fk:currentRoom()
  local ret = {}
  for _, s in ipairs(toget) do
    if not self:hasSkill(s) then
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

---@param skill string | Skill
---@param source_skill string | Skill | nil
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
  local tolose = self.derivative_skills[skill]
  table.insert(tolose, skill)
  self.derivative_skills[skill] = nil

  local ret = {}  ---@type Skill[]
  for _, s in ipairs(tolose) do
    if not self:hasSkill(s) then
      table.insert(ret, s)
    end
  end
  return ret
end

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

return Player
