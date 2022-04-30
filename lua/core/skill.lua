---@class Skill : Object
---@field name string
---@field frequency Frequency
---@field visible boolean
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
end

return Skill
