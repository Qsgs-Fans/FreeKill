---@class TriggerSkill : UsableSkill
---@field global boolean
---@field events Event[]
---@field refresh_events Event[]
---@field priority_table table<Event, number>
local TriggerSkill = UsableSkill:subclass("TriggerSkill")

function TriggerSkill:initialize(name, frequency)
  UsableSkill.initialize(self, name, frequency)

  self.global = false
  self.events = {}
  self.refresh_events = {}
  self.priority_table = {}  -- GameEvent --> priority
end

-- Default functions

---Determine whether a skill can refresh at this moment
---@param event Event @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
function TriggerSkill:canRefresh(event, target, player, data) return false end

---Refresh the skill (e.g. clear marks)
---@param event Event @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
function TriggerSkill:refresh(event, target, player, data) end

---Determine whether a skill can trigger at this moment
---@param event Event @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean
function TriggerSkill:triggerable(event, target, player, data)
  return target and (target == player)
    and (self.global or target:hasSkill(self))
end

-- Determine how to cost this skill.
---@param event Event @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean @ returns true if trigger is broken
function TriggerSkill:trigger(event, target, player, data)
  return self:doCost(event, target, player, data)
end

-- do cost and skill effect.
-- DO NOT modify this function
function TriggerSkill:doCost(event, target, player, data)
  local ret = self:cost(event, target, player, data)
  if ret then
    return player.room:useSkill(player, self, function()
      return self:use(event, target, player, data)
    end)
  end
end

-- ask player how to use this skill.
---@param event Event @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean @ returns true if trigger is broken
function TriggerSkill:cost(event, target, player, data)
  local ret = false
  if self.frequency == Skill.Compulsory then
    return true
  end

  if player.room:askForSkillInvoke(player, self.name) then
    return true
  end
  return false
end

---Use this skill
---@param event Event @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean
function TriggerSkill:use(event, target, player, data) end

return TriggerSkill
