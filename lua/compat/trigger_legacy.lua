-- SPDX-License-Identifier: GPL-3.0-or-later

-- 牢triggerSkill

---@class LegacyTriggerSkill : UsableSkill
---@field public global boolean
---@field public events (TriggerEvent|integer|string)[]
---@field public refresh_events (TriggerEvent|integer|string)[]
---@field public priority_table table<(TriggerEvent|integer|string), number>
local LegacyTriggerSkill = UsableSkill:subclass("LegacyTriggerSkill")

function LegacyTriggerSkill:initialize(name, frequency)
  UsableSkill.initialize(self, name, frequency)

  self.global = false
  self.events = {}
  self.refresh_events = {}
  self.priority_table = {}  -- GameEvent --> priority
end

-- Default functions

---Determine whether a skill can refresh at this moment
---@param event TriggerEvent|integer|string @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
function LegacyTriggerSkill:canRefresh(event, target, player, data) return false end

---Refresh the skill (e.g. clear marks)
---@param event TriggerEvent|integer|string @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
function LegacyTriggerSkill:refresh(event, target, player, data) end

---Determine whether a skill can trigger at this moment
---@param event TriggerEvent|integer|string @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean
function LegacyTriggerSkill:triggerable(event, target, player, data)
  return target and (target == player)
    and (self.global or target:hasSkill(self))
end

-- Determine how to cost this skill.
---@param event TriggerEvent|integer|string @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean @ returns true if trigger is broken
function LegacyTriggerSkill:trigger(event, target, player, data)
  return self:doCost(event, target, player, data)
end

-- do cost and skill effect.
-- DO NOT modify this function
function LegacyTriggerSkill:doCost(event, target, player, data)
  local start_time = os.getms()
  local room = player.room
  room.current_cost_skill = self
  local ret = self:cost(event, target, player, data)
  local end_time = os.getms()

  local room = player.room
  -- 对于那种cost直接返回true的锁定技，如果是预亮技，那么还是询问一下好
  if ret and player:isFakeSkill(self) and end_time - start_time < 1000 and
    (self.main_skill and self.main_skill or self).visible then
    ret = room:askToSkillInvoke(player, { skill_name = self.name })
  end
  room.current_cost_skill = nil

  local cost_data_bak = self.cost_data
  room.logic:trigger(fk.BeforeLegacyTriggerSkillUse, player, { skill = self, willUse = ret })
  self.cost_data = cost_data_bak

  if ret then
    local skill_data = {cost_data = cost_data_bak, tos = {}, cards = {}}
    if type(cost_data_bak) == "table" then
      if type(cost_data_bak.tos) == "table" and #cost_data_bak.tos > 0 and type(cost_data_bak.tos[1]) == "number" and
      room:getPlayerById(cost_data_bak.tos[1]) ~= nil then
        skill_data.tos = cost_data_bak.tos
      end
      if type(cost_data_bak.cards) == "table" then skill_data.cards = cost_data_bak.cards end
    end
    return room:useSkill(player, self, function()
      return self:use(event, target, player, data)
    end, skill_data)
  end
end

-- ask player how to use this skill.
---@param event TriggerEvent|integer|string @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean @ returns true if trigger is broken
function LegacyTriggerSkill:cost(event, target, player, data)
  local ret = false
  if self.frequency == Skill.Compulsory or self.frequency == Skill.Wake then
    return true
  end

  if player.room:askToSkillInvoke(player, { skill_name = self.name }) then
    return true
  end
  return false
end

---Use this skill
---@param event TriggerEvent|integer|string @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean?
function LegacyTriggerSkill:use(event, target, player, data) end

function LegacyTriggerSkill:canWake(event, target, player, data)
  return true
end

---@param event TriggerEvent|integer|string @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean
function LegacyTriggerSkill:enableToWake(event, target, player, data)
  return
    type(player:getMark(MarkEnum.StraightToWake)) == "table" and
    table.find(player:getMark(MarkEnum.StraightToWake), function(skillName)
      return self.name == skillName
    end) or
    self:canWake(event, target, player, data)
end

return LegacyTriggerSkill
