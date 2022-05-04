---@class Player : Object
---@field id integer
---@field hp integer
---@field maxHp integer
---@field kingdom string
---@field role string
---@field general string
---@field handcard_num integer
---@field seat integer
---@field phase Phase
---@field faceup boolean
---@field chained boolean
---@field dying boolean
---@field dead boolean
---@field state string
---@field player_skills Skill[]
---@field flag string[]
---@field tag table<string, any>
---@field mark table<string, integer>
---@field player_cards table<integer, integer[]>
---@field special_cards table<string, integer[]>
---@field cardUsedHistory table<string, integer>
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

function Player:initialize()
  self.id = 114514
  self.hp = 0
  self.maxHp = 0
  self.kingdom = "qun"
  self.role = ""
  self.general = ""
  self.seat = 0
  self.phase = Player.PhaseNone
  self.faceup = true
  self.chained = false
  self.dying = false
  self.dead = false
  self.state = ""

  self.player_skills = {}
  self.flag = {}
  self.tag = {}
  self.mark = {}
  self.player_cards = {
    [Player.Hand] = {},
    [Player.Equip] = {},
    [Player.Judge] = {},
  }
  self.special_cards = {}

  self.cardUsedHistory = {}
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

  return baseValue
end

---@param subtype CardSubtype
---@return integer|null
function Player:getEquipBySubtype(subtype)
  local equipId = nil
  for _, id in ipairs(self.player_cards[Player.Equip]) do
    if Fk:getCardById(id).sub_type == subtype then
      equipId = id
      break
    end
  end

  return equipId
end

function Player:getAttackRange()
  local weapon = Fk:getCardById(self:getEquipBySubtype(Card.SubtypeWeapon))
  local baseAttackRange = math.max(weapon and weapon.attack_range or 1, 0)

  return math.max(baseAttackRange, 0)
end

---@param other Player
function Player:distanceTo(other)
  local right = math.abs(self.seat - other.seat)
  local left = #Fk:currentRoom().alive_players - right
  local ret = math.min(left, right)
  -- TODO: corrent distance here using skills
  return math.max(ret, 1)
end

---@param other Player
function Player:inMyAttackRange(other)
  return self ~= other and self:distanceTo(other) <= self:getAttackRange()
end

function Player:addCardUseHistory(cardName, num)
  assert(type(num) == "number" and num ~= 0)

  self.cardUsedHistory[cardName] = self.cardUsedHistory[cardName] or 0
  self.cardUsedHistory[cardName] = self.cardUsedHistory[cardName] + num
end

function Player:resetCardUseHistory(cardName)
  if self.cardUsedHistory[cardName] then
    self.cardUsedHistory[cardName] = 0
  end
end

return Player
