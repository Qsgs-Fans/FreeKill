---@class Engine : Object
---@field packages table<string, Package>
---@field package_names string[]
---@field skills table<string, Skill>
---@field related_skills table<string, Skill[]>
---@field global_trigger TriggerSkill[]
---@field global_status_skill table<class, Skill[]>
---@field generals table<string, General>
---@field same_generals table<string, string[]>
---@field lords string[]
---@field cards Card[]
---@field translations table<string, table<string, string>>
---@field game_modes table<string, GameMode>
---@field disabled_packs string[]
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
  self.global_status_skill = {}
  self.generals = {}    -- name --> General
  self.same_generals = {}
  self.lords = {}     -- lordName[]
  self.cards = {}     -- Card[]
  self.translations = {}  -- srcText --> translated
  self.game_modes = {}
  self.disabled_packs = {}

  self:loadPackages()
  self:addSkills(AuxSkills)
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
  self:addGameModes(pack.game_modes)
end

function Engine:loadPackages()
  local directories = FileIO.ls("packages")

  -- load standard & standard_cards first
  self:loadPackage(require("packages.standard"))
  self:loadPackage(require("packages.standard_cards"))
  table.removeOne(directories, "standard")
  table.removeOne(directories, "standard_cards")

  for _, dir in ipairs(directories) do
    if (not string.find(dir, ".disabled")) and FileIO.isDir("packages/" .. dir)
      and FileIO.exists("packages/" .. dir .. "/init.lua") then
      local pack = require(string.format("packages.%s", dir))
      -- Note that instance of Package is a table too
      -- so dont use type(pack) == "table" here
      if type(pack) == "table" then
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
end

---@param t table
function Engine:loadTranslationTable(t, lang)
  assert(type(t) == "table")
  lang = lang or "zh_CN"
  self.translations[lang] = self.translations[lang] or {}
  for k, v in pairs(t) do
    self.translations[lang][k] = v
  end
end

function Engine:translate(src)
  local lang = Config.language or "zh_CN"
  if not self.translations[lang] then lang = "zh_CN" end
  local ret = self.translations[lang][src]
  return ret or src
end

---@param skill Skill
function Engine:addSkill(skill)
  assert(skill.class:isSubclassOf(Skill))
  if self.skills[skill.name] ~= nil then
    error(string.format("Duplicate skill %s detected", skill.name))
  end
  self.skills[skill.name] = skill

  if skill.global then
    if skill:isInstanceOf(TriggerSkill) then
      table.insert(self.global_trigger, skill)
    else
      local t = self.global_status_skill
      t[skill.class] = t[skill.class] or {}
      table.insert(t[skill.class], skill)
    end
  end

  for _, s in ipairs(skill.related_skills) do
    self:addSkill(s)
  end
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

  if general.name ~= general.trueName then
    local tName = general.trueName
    self.same_generals[tName] = self.same_generals[tName] or { tName }
    table.insert(self.same_generals[tName], general.name)
  end
end

---@param generals General[]
function Engine:addGenerals(generals)
  assert(type(generals) == "table")
  for _, general in ipairs(generals) do
    self:addGeneral(general)
  end
end

---@param name string
function Engine:getSameGenerals(name)
  local tmp = name:split("__")
  local tName = tmp[#tmp]
  local ret = self.same_generals[tName] or {}
  return table.filter(ret, function(g)
    return self.generals[g] ~= nil
  end)
end

local cardId = 1
local _card_name_table = {}
---@param card Card
function Engine:addCard(card)
  assert(card.class:isSubclassOf(Card))
  card.id = cardId
  cardId = cardId + 1
  table.insert(self.cards, card)
  if _card_name_table[card.name] == nil then
    _card_name_table[card.name] = card
  end
end

---@param cards Card[]
function Engine:addCards(cards)
  for _, card in ipairs(cards) do
    self:addCard(card)
  end
end

---@param name string
---@param suit Suit
---@param number integer
---@return Card
function Engine:cloneCard(name, suit, number)
  local cd = _card_name_table[name]
  assert(cd, "Attempt to clone a card that not added to engine")
  local ret = cd:clone(suit, number)
  ret.package = cd.package
  return ret
end

---@param game_modes GameMode[]
function Engine:addGameModes(game_modes)
  for _, s in ipairs(game_modes) do
    self:addGameMode(s)
  end
end

---@param game_mode GameMode
function Engine:addGameMode(game_mode)
  assert(game_mode:isInstanceOf(GameMode))
  if self.game_modes[game_mode.name] ~= nil then
    error(string.format("Duplicate game_mode %s detected", game_mode.name))
  end
  self.game_modes[game_mode.name] = game_mode
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

  generalPool = generalPool or self:getAllGenerals()
  except = except or {}
  for _, g in ipairs(self.packages["test_p_0"].generals) do
    table.insert(except, g.name)
  end

  local availableGenerals = {}
  for _, general in pairs(generalPool) do
    if not table.contains(except, general.name) and not (filter and filter(general)) then
      if #table.filter(availableGenerals, function(g)
        return g.trueName == general.trueName
      end) == 0 then
        table.insert(availableGenerals, general)
      end
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
  for _, general in pairs(self.generals) do
    if not (except and table.contains(except, general)) then
      if not table.contains(self.disabled_packs, general.package.name) then
        table.insert(result, general)
      end
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
      if not table.contains(self.disabled_packs, card.package.name) then
        table.insert(result, card.id)
      end
    end
  end

  return result
end

local filtered_cards = {}

---@param id integer
---@param ignoreFilter boolean
---@return Card
function Engine:getCardById(id, ignoreFilter)
  local ret = self.cards[id]
  if not ignoreFilter then
    ret = filtered_cards[id] or self.cards[id]
  end
  return ret
end

---@param id integer
---@param player Player
---@param data any @ may be JudgeStruct
function Engine:filterCard(id, player, data)
  local card = self:getCardById(id, true)
  if player == nil then
    filtered_cards[id] = nil
    return
  end
  local skills = player:getAllSkills()
  local filters = {}
  for _, s in ipairs(skills) do
    if s:isInstanceOf(FilterSkill) then
      table.insert(filters, s)
    end
  end
  if #filters == 0 then
    filtered_cards[id] = nil
    return
  end

  local modify = false
  if data and type(data) == "table" and data.card
    and type(data.card) == "table" and data.card:isInstanceOf(Card) then
    modify = true
  end

  for _, f in ipairs(filters) do
    if f:cardFilter(card) then
      local _card = f:viewAs(card)
      _card.id = id
      _card.skillName = f.name
      if modify and RoomInstance then
        if not f.mute then
          RoomInstance:broadcastSkillInvoke(f.name)
        end
        RoomInstance:doAnimate("InvokeSkill", {
          name = f.name,
          player = player.id,
          skill_type = f.anim_type,
        })
        RoomInstance:sendLog{
          type = "#FilterCard",
          arg = f.name,
          from = player.id,
          arg2 = card:toLogString(),
          arg3 = _card:toLogString(),
        }
      end
      card = _card
    end
    if card == nil then
      card = self:getCardById(id)
    end
    filtered_cards[id] = card
  end

  if modify then
    filtered_cards[id] = nil
    data.card = card
    return
  end
end

function Engine:currentRoom()
  if RoomInstance then
    return RoomInstance
  end
  return ClientInstance
end

function Engine:getDescription(name)
  return self:translate(":" .. name)
end

return Engine
