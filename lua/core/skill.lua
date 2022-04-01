---@class Skill : Object
---@field name string
---@field frequency integer # enum Frequency
local Skill = class("Skill")

-- enum Frequency
fk.createEnum(Skill, {
    "Frequent",
    "NotFrequent",
    "Compulsory",
    "Limited",
    "Wake",
})

function Skill:initialize(name, frequency)
    -- TODO: visible, lord, etc
    self.name = name
    self.frequency = frequency
end

return Skill
