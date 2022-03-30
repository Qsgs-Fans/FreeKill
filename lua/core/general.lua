---@class General : Object
---@field package Package
---@field name string
---@field kingdom string
---@field hp number
---@field maxHp number
---@field gender number
---@field skills table
---@field other_skills table
General = class("General")

-- enum Gender
General.Male = 0
General.Female = 1

function General:initialize(package, name, kingdom, hp, maxHp, gender, initialHp)
    self.package = package
    self.name = name
    self.kingdom = kingdom
    self.hp = hp
    self.maxHp = maxHp or hp
    self.gender = gender or General.Male

    self.skills = {}        -- Skill[]
    -- skill belongs other general, e.g. "mashu" of pangde
    self.other_skills = {}  -- string[]
end

---@param skill any
function General:addSkill(skill)
    if (type(skill) == "string") then
        table.insert(self.other_skills, skill)
    elseif (skill.class and skill.class:isSubclassOf(Skill)) then
        table.insert(self.skills, skill)
    end
end

return General
