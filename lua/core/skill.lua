---@class Skill
local Skill = class("Skill")

fk.createEnum(Skill, {
    "Common",
    "Frequent",
    "Compulsory",
    "Awaken",
    "Limit",
})

function Skill:initialize(name, skillType)
    self.name = name
    self.description = ":" .. name
    self.skillType = skillType
end

local TriggerSkill = class("TriggerSkill", Skill)

function TriggerSkill:initialize(spec)
    Skill.initialize(self, spec.name, spec.skillType)
    self.isRefreshAt = spec.isRefreshAt
    self.isTriggerable = spec.isTriggerable
    self.targetFilter = spec.targetFilter
    self.cardFilter = spec.cardFilter
    self.beforeTrigger = spec.beforeTrigger
    self.onTrigger = spec.onTrigger
end

return Skill
