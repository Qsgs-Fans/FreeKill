---@class TriggerSkill : Skill
---@field global boolean
---@field events table
---@field refresh_events table
---@field priority_table table
local TriggerSkill = Skill:subclass("TriggerSkill")

function TriggerSkill:initialize(name, frequency)
    Skill.initialize(self, name, frequency)

    self.global = false
    self.events = {}
    self.refresh_events = {}
    self.priority_table = {}
end

-- Default functions

function TriggerSkill:canRefresh(event, target, player, data) return false end

function TriggerSkill:refresh(event, target, player, data) end

function TriggerSkill:triggerable(event, target, player, data)
    return target and (self.global or (target.alive == true and target:hasSkill(self)))
end

function TriggerSkill:trigger(event, target, player, data) end

function TriggerSkill:use(event, target, player, data) end

return TriggerSkill
