-- SPDX-License-Identifier: GPL-3.0-or-later

---@class Skill : Object
---@field public name string
---@field public trueName string
---@field public package Package
---@field public frequency Frequency
---@field public visible boolean
---@field public mute boolean
---@field public anim_type string
---@field public related_skills Skill[]
---@field public attached_equip string
local Skill = class("Skill")

---@alias Frequency integer

Skill.Frequent = 1
Skill.NotFrequent = 2
Skill.Compulsory = 3
Skill.Limited = 4
Skill.Wake = 5

function Skill:initialize(name, frequency)
  -- TODO: visible, lord, etc
  self.name = name
  -- skill's package is assigned when calling General:addSkill
  -- if you need skills that not belongs to any general (like 'jixi')
  -- then you should assign skill.package explicitly
  self.package = { extensionName = "standard" }
  self.frequency = frequency
  self.visible = true
  self.mute = false
  self.anim_type = ""
  self.related_skills = {}

  local name_splited = name:split("__")
  self.trueName = name_splited[#name_splited]

  if string.sub(name, 1, 1) == "#" then
    self.visible = false
  end

  self.attached_equip = nil
end

---@param skill Skill
function Skill:addRelatedSkill(skill)
  table.insert(self.related_skills, skill)
end

---@return boolean
function Skill:isEquipmentSkill()
  return self.attached_equip and type(self.attached_equip) == 'string' and self.attached_equip ~= ""
end

---@param player Player
---@return boolean
function Skill:isEffectable(player)
  local nullifySkills = Fk:currentRoom().status_skills[InvaliditySkill] or {}
  for _, nullifySkill in ipairs(nullifySkills) do
    if self.name ~= nullifySkill.name and nullifySkill:getInvalidity(player, self) then
      return false
    end
  end

  return true
end

return Skill
