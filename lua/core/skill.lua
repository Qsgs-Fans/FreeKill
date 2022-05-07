---@class Skill : Object
---@field name string
---@field frequency Frequency
---@field visible boolean
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
  self.frequency = frequency
  self.visible = true
  self.related_skills = {}
end

---@param skill Skill
function Skill:addRelatedSkill(skill)
  table.insert(self.related_skills, skill)
end

return Skill
