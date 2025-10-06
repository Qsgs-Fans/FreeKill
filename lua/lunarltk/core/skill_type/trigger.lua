-- SPDX-License-Identifier: GPL-3.0-or-later

--[[
  此为触发技，属于可发动技能。
--]]

---@class TriggerSkill : UsableSkill
---@field public global boolean @ 是否为全局事件
---@field public event TriggerEvent @ 事件时机
---@field public priority number @ 优先级，越大越优先（默认1，装备默认0.1，游戏规则为0）
---@field public late_refresh? boolean @ 仅用于Refresh，表示该触发技的refresh在trigger之后执行
local TriggerSkill = UsableSkill:subclass("TriggerSkill")

function TriggerSkill:initialize(name, frequency)
  UsableSkill.initialize(self, name, frequency)

  self.global = false
  self.priority = 1
end

-- Default functions

---Determine whether a skill can refresh at this moment
---@param event TriggerEvent @ TriggerEvent
---@param target ServerPlayer? @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
function TriggerSkill:canRefresh(event, target, player, data) return false end

---Refresh the skill (e.g. clear marks)
---@param event TriggerEvent @ TriggerEvent
---@param target ServerPlayer? @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
function TriggerSkill:refresh(event, target, player, data) end

---Determine whether a skill can trigger at this moment
---@param event TriggerEvent @ TriggerEvent
---@param target ServerPlayer? @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean?
function TriggerSkill:triggerable(event, target, player, data)
  return target and (target == player)
    and (self.global or target:hasSkill(self:getSkeleton().name))
end

-- Determine how to cost this skill.
---@param event TriggerEvent @ TriggerEvent
---@param target ServerPlayer? @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean? @ returns true if trigger is broken
function TriggerSkill:trigger(event, target, player, data)
  event:setSkillData(self, "cancel_cost", false)
  return self:doCost(event, target, player, data)
end

-- do cost and skill effect.
-- DO NOT modify this function
---@param event TriggerEvent @ TriggerEvent
---@return boolean? @ returns true if skill is invoked and trigger is broken
function TriggerSkill:doCost(event, target, player, data)
  local start_time = os.getms()
  local room = player.room ---@type Room
  room.current_cost_skill = self
  local ret = self:cost(event, target, player, data) -- 执行消耗
  local end_time = os.getms()

  -- 对于那种cost直接返回true的锁定技，如果是预亮技，应询问
  if ret and player:isFakeSkill(self) and end_time - start_time < 1000 and
    (self.main_skill and self.main_skill or self).visible then
    ret = room:askToSkillInvoke(player, { skill_name = self.name })
  end
  room.current_cost_skill = nil

  local cost_data_bak = event:getCostData(self)
  room.logic:trigger(fk.BeforeTriggerSkillUse, player, { skill = self, willUse = ret })
  --self.cost_data = cost_data_bak

  if ret then -- 如果完成了消耗，则执行技能效果，并判断是否要终结此时机
    local skill_data = {cost_data = cost_data_bak, tos = {}, cards = {}}
    if cost_data_bak and type(cost_data_bak) == "table" then
      skill_data.tos = cost_data_bak.tos
      skill_data.cards = cost_data_bak.cards
    end
    local skillEffectData = room:useSkill(player, self, function()
      return self:use(event, target, player, data)
    end, skill_data)
    return skillEffectData.trigger_break
  end
  event:setSkillData(self, "cancel_cost", true)
end

-- ask player how to use this skill.
---@param event TriggerEvent @ TriggerEvent
---@param target ServerPlayer? @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean? @ returns true if trigger is broken
function TriggerSkill:cost(event, target, player, data)
  if self:hasTag(Skill.Compulsory) or self.is_delay_effect then
    return true
  end

  if player.room:askToSkillInvoke(player, { skill_name = self.name }) then
    return true
  end
  return false
end

---Use this skill
---@param event TriggerEvent @ TriggerEvent
---@param target ServerPlayer? @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean?
function TriggerSkill:use(event, target, player, data) end

--- 是否满足觉醒条件，默认是
function TriggerSkill:canWake(event, target, player, data)
  return true
end

---@param event TriggerEvent @ TriggerEvent
---@param target ServerPlayer? @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return boolean?
function TriggerSkill:enableToWake(event, target, player, data)
  return
    type(player:getMark(MarkEnum.StraightToWake)) == "table" and
    table.find(player:getMark(MarkEnum.StraightToWake), function(skillName)
      return self.name == skillName
    end) or
    self:canWake(event, target, player, data)
end

-- 技能于单角色单时机内的发动次数上限
---@param event TriggerEvent @ TriggerEvent
---@param target ServerPlayer? @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
---@return number @ 次数上限
function TriggerSkill:triggerableTimes(event, target, player, data)
  return 1
end

return TriggerSkill
