-- SPDX-License-Identifier: GPL-3.0-or-later

---@class General : Object
---@field public package Package
---@field public name string
---@field public trueName string
---@field public kingdom string
---@field public hp integer
---@field public maxHp integer
---@field public gender Gender
---@field public skills Skill[]
---@field public other_skills string[]
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
