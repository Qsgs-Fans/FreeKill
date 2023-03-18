---@class General : Object
---@field package Package
---@field name string
---@field trueName string
---@field kingdom string
---@field hp integer
---@field maxHp integer
---@field gender Gender
---@field skills Skill[]
---@field other_skills string[]
General = class("General")

---@alias Gender integer

General.Male = 1
General.Female = 2

function General:initialize(package, name, kingdom, hp, maxHp, gender)
  self.package = package
  self.name = name
  local name_splited = name:split("__")
  self.trueName = name_splited[#name_splited]

  self.kingdom = kingdom
  self.hp = hp
  self.maxHp = maxHp or hp
  self.gender = gender or General.Male

  self.skills = {}    -- skills first added to this general
  self.other_skills = {}  -- skill belongs other general, e.g. "mashu" of pangde

  package:addGeneral(self)
end

---@param skill Skill
function General:addSkill(skill)
  if (type(skill) == "string") then
    table.insert(self.other_skills, skill)
  elseif (skill.class and skill.class:isSubclassOf(Skill)) then
    table.insert(self.skills, skill)
    skill.package = self.package
  end
end

return General
