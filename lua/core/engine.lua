---@class Engine : Object
---@field packages table
---@field skills table
---@field related_skills table
---@field generals table
---@field lords table
---@field cards table
---@field translations table
local Engine = class("Engine")

function Engine:initialize()
    -- Engine should be singleton
    if Fk ~= nil then
        error("Engine has been initialized")
        return
    end

    Fk = self

    self.packages = {}      -- name --> Package
    self.skills = {}        -- name --> Skill
    self.related_skills = {} -- skillName --> relatedName
    self.generals = {}      -- name --> General
    self.lords = {}         -- lordName[]
    self.cards = {}         -- Card[]
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

    -- add cards, generals and skills to Engine
    if pack.type == Package.CardPack then
        self:addCards(pack.cards)
    elseif pack.type == Package.GeneralPack then
        self:addGenerals(pack.generals)
    end
    self:addSkills(pack:getSkills())
end

function Engine:loadPackages()
    assert(FileIO.isDir("packages"))
    FileIO.cd("packages")
    for _, dir in ipairs(FileIO.ls()) do
        if FileIO.isDir(dir) then
            self:loadPackage(require(dir))
        end
    end
    FileIO.cd("..")
end

---@param t table
function Engine:loadTranslationTable(t)
    assert(type(t) == "table")
    for k, v in pairs(t) do
        self.translations[k] = v
    end
end

---@param skill any
function Engine:addSkill(skill)
    assert(skill.class:isSubclassOf(Skill))
    if self.skills[skill.name] ~= nil then
        error(string.format("Duplicate skill %s detected", skill.name))
    end
    self.skills[skill.name] = skill
end

---@param skills any[]
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

function Engine:addCard(card)
    assert(card.class:isSubclassOf(Card))
    table.insert(self.cards, card)
end

function Engine:addCards(cards)
    assert(type(cards) == "table")
    for _, card in ipairs(cards) do
        self:addCard(card)
    end
end

---@param num number
---@param generalPool General[]
---@param except string[]
---@param filter function
---@return General[] generals
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

return Engine
