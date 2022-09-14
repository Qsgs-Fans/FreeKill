---@class Engine : Object
---@field packages table<string, Package>
---@field package_names string[]
---@field skills table<string, Skill>
---@field related_skills table<string, Skill[]>
---@field global_trigger TriggerSkill[]
---@field generals table<string, General>
---@field lords string[]
---@field cards Card[]
---@field translations table<string, string>
local Engine = class("Engine")

function Engine:initialize()
  -- Engine should be singleton
  if Fk ~= nil then
    error("Engine has been initialized")
    return
  end

  Fk = self

  self.packages = {}    -- name --> Package
  self.package_names = {}
  self.skills = {}    -- name --> Skill
  self.related_skills = {} -- skillName --> relatedSkill[]
  self.global_trigger = {}
  self.generals = {}    -- name --> General
  self.lords = {}     -- lordName[]
  self.cards = {}     -- Card[]
  self.translations = {}  -- srcText --> translated

  self:loadPackages()
end

---@param pack Package
function Engine:loadPackage(pack)
  assert(pack:isInstanceOf(Package))
  if self.packages[pack.name] ~= nil then 
    error(string.format("Duplicate package %s detected", pack.name))
  end
  self.packages[pack.name] = pack
  table.insert(self.package_names, pack.name)

  -- add cards, generals and skills to Engine
  if pack.type == Package.CardPack then
    self:addCards(pack.cards)
  elseif pack.type == Package.GeneralPack then
    self:addGenerals(pack.generals)
  end
  self:addSkills(pack:getSkills())
end

function Engine:loadPackages()
  local directories = FileIO.ls("packages")

  -- load standard & standard_cards first
  self:loadPackage(require("packages.standard"))
  self:loadPackage(require("packages.standard_cards"))
  table.removeOne(directories, "standard")
  table.removeOne(directories, "standard_cards")

  for _, dir in ipairs(directories) do
    if FileIO.isDir("packages/" .. dir) then
      local pack = require(string.format("packages.%s", dir))
      -- Note that instance of Package is a table too
      -- so dont use type(pack) == "table" here
      if pack[1] ~= nil then
        for _, p in ipairs(pack) do
          self:loadPackage(p)
        end
      else
        self:loadPackage(pack)
      end
    end
  end
end

---@param t table
function Engine:loadTranslationTable(t)
  assert(type(t) == "table")
  for k, v in pairs(t) do
    self.translations[k] = v
  end
end

function Engine:translate(src)
  local ret = self.translations[src]
  if not ret then return src end
  return ret
end

---@param skill Skill
function Engine:addSkill(skill)
  assert(skill.class:isSubclassOf(Skill))
  if self.skills[skill.name] ~= nil then
    error(string.format("Duplicate skill %s detected", skill.name))
  end
  self.skills[skill.name] = skill
end

---@param skills Skill[]
function Engine:addSkills(skills)
  assert(type(skills) == "table")
  for _, skill in ipairs(skills) do
    self:addSkill(skill)
  end
end

---@param general General
function Engine:addGeneral(general)
  assert(general:isInstanceOf(General))
  if self.generals[general.name] ~= nil then
    error(string.format("Duplicate general %s detected", general.name))
  end
  self.generals[general.name] = general
end

---@param generals General[]
function Engine:addGenerals(generals)
  assert(type(generals) == "table")
  for _, general in ipairs(generals) do
    self:addGeneral(general)
  end
end

local cardId = 1
---@param card Card
function Engine:addCard(card)
  assert(card.class:isSubclassOf(Card))
  card.id = cardId
  cardId = cardId + 1
  table.insert(self.cards, card)
end

---@param cards Card[]
function Engine:addCards(cards)
  for _, card in ipairs(cards) do
    self:addCard(card)
  end
end

---@param num integer
---@param generalPool General[]
---@param except string[]
---@param filter function
---@return General[]
function Engine:getGeneralsRandomly(num, generalPool, except, filter)
  if filter then
    assert(type(filter) == "function")
  end

  generalPool = generalPool or self.generals
  except = except or {}

  local availableGenerals = {}
  for _, general in pairs(generalPool) do
    if not table.contains(except, general.name) and not (filter and filter(general)) then
      table.insert(availableGenerals, general)
    end
  end

  if #availableGenerals == 0 then
    return {}
  end

  local result = {}
  for i = 1, num do
    local randomGeneral = math.random(1, #availableGenerals)
    table.insert(result, availableGenerals[randomGeneral])
    table.remove(availableGenerals, randomGeneral)

    if #availableGenerals == 0 then
      break
    end
  end

  return result
end

---@param except General[]
---@return General[]
function Engine:getAllGenerals(except)
  local result = {}
  for _, general in ipairs(self.generals) do
    if not (except and table.contains(except, general)) then
      table.insert(result, general)
    end
  end

  return result
end

---@param except integer[]
---@return integer[]
function Engine:getAllCardIds(except)
  local result = {}
  for _, card in ipairs(self.cards) do
    if not (except and table.contains(except, card.id)) then
      table.insert(result, card.id)
    end
  end

  return result
end

---@param id integer
---@return Card
function Engine:getCardById(id)
  return self.cards[id]
end

function Engine:currentRoom()
  if ClientInstance then
    return ClientInstance
  end
  return RoomInstance
end

return Engine
