---@class Skill : Object
---@field name string
---@field package Package
---@field frequency Frequency
---@field visible boolean
---@field mute boolean
---@field anim_type string
---@field related_skills Skill[]
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

return Skill
