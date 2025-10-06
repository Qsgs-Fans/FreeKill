---@class TriggerEvent: Object
---@field public id integer
---@field public room Room
---@field public target ServerPlayer?
---@field public data any 具体的触发时机会继承这个类 进而获得具体的data类型
---@field public skill_data table<string, table<string, any>>
---  某个技能在这个event范围内的数据，比如costData之类的
---@field public finished_skills string[] 已经发动完了的技能 不会再进行检测
---@field public refresh_only boolean? 这次triggerEvent是不是仅执行refresh
---@field public invoked_times table<string, number> 技能于单角色单个时机内发动过的次数
local TriggerEvent = class("TriggerEvent")

function TriggerEvent:initialize(room, target, data)
  self.room = room
  self.target = target
  self.data = data
  local logic = room.logic
  logic.current_trigger_event_id = logic.current_trigger_event_id + 1
  self.id = logic.current_trigger_event_id

  self.skill_data = {}
  self.finished_skills = {}
  self.invoked_times = {}
end

---[[
function TriggerEvent:__eq(other)
  --经实测 global event 是TriggerSkill的event.class
  local function eventName(obj)
    return obj.name or obj.class.name
  end
  return eventName(self) == eventName(other)
end
--]]

---@param skill Skill
---@param k string
---@param v any
function TriggerEvent:setSkillData(skill, k, v)
  local name = skill.name
  self.skill_data[name] = self.skill_data[name] or {}
  self.skill_data[name][k] = v
end

---@param skill Skill
---@param k string
function TriggerEvent:getSkillData(skill, k)
  local name = skill.name
  return self.skill_data[name] and self.skill_data[name][k]
end

---@param skill Skill
---@param v CostData|any @ cost_data，建议为键值表，```tos```(ServerPlayer[])为目标、```cards```(integer[])为牌
function TriggerEvent:setCostData(skill, v)
  self:setSkillData(skill, "cost_data", v)
end

---@param skill Skill
---@return CostData|any
function TriggerEvent:getCostData(skill)
  return self:getSkillData(skill, "cost_data")
end

--- 本事件是否要应该停止询问
function TriggerEvent:breakCheck()
  return false
end

---@param skill Skill
function TriggerEvent:isCancelCost(skill)
  return not not self:getSkillData(skill, "cancel_cost")
end

-- 先执行带refresh的，再执行带效果的
function TriggerEvent:exec()
  local room, logic = self.room, self.room.logic
  local skills = logic.skill_table[self.class] or Util.DummyTable ---@type TriggerSkill[]
  if #skills == 0 then return false end

  local _target = room.current -- for iteration
  local player = _target
  local event = self.class
  local target = self.target
  local data = self.data

  repeat do
    -- refresh skills. This should not be broken
    for _, skill in ipairs(skills) do
      if skill:canRefresh(self, target, player, data) and not skill.late_refresh then
        skill:refresh(self, target, player, data)
      end
    end
    player = player.next
  end until player == _target

  local cur_event = logic:getCurrentEvent() or Util.DummyTable
  -- 如果当前事件被杀，就强制只refresh
  -- 因为被杀的事件再进行正常trigger只可能在cleaner和exit了
  self.refresh_only = self.refresh_only or cur_event.killed
  local broken = false
  if not self.refresh_only then

    local prio_tab = logic.skill_priority_table[event]
    local prev_prio = math.huge

    for _, prio in ipairs(prio_tab) do
      if broken then break end
      if prio >= prev_prio then
        goto continue
      end

      repeat do
        self.invoked_times = {}
        local triggerableLimit = {}
        ---@param skill TriggerSkill
        local filter_func = function(skill)
          local invokedTimes = self.invoked_times[skill.name] or 0
          if skill.priority ~= prio or invokedTimes == -1 then
            return false
          end

          local times = skill:triggerableTimes(self, target, player, data)
          if (self.invoked_times[skill.name] or 0) < times and skill:triggerable(self, target, player, data) then
            if times > 1 then
              triggerableLimit[skill.name] = times
            end

            return true
          end

          return false
        end

        local skill_available = table.filter(skills, filter_func)

        local playerSkillFinished = false
        while #skill_available > 0 do
          local player_skills = {}
          if not playerSkillFinished then
            player_skills = table.filter(skill_available, function(s) return s:isPlayerSkill(player, true) end)
            playerSkillFinished = #player_skills == 0
          else
            skill_available = table.filter(skill_available, function(s) return not s:isPlayerSkill(player, true) end)
            if #skill_available == 0 then
              break
            end
          end

          local formatChoiceName = function (skill)
            local leftTimes = (triggerableLimit[skill.name] or 1) - (self.invoked_times[skill.name] or 0)
            if leftTimes > 1 then
              return "#skill_muti_trigger:::" .. skill.name .. ":" .. leftTimes
            end

            return skill.name
          end
          local skill_name = prio <= 0 and skill_available[1].name or
          room:askToChoice(player, { skill_name = "trigger", prompt = "#choose-trigger",
            choices = table.map(#player_skills > 0 and player_skills or skill_available, function (skill)
              return formatChoiceName(skill)
            end)
          })

          if skill_name:startsWith("#skill_muti_trigger") then
            local strSplited = skill_name:split(":")
            skill_name = strSplited[#strSplited - 1]
          end

          local skill = Fk.skills[skill_name]
          ---@cast skill TriggerSkill

          self.invoked_times[skill.name] = (self.invoked_times[skill.name] or 0) + 1
          broken = skill:trigger(self, target, player, data) or self:breakCheck() or cur_event.killed
          if self:isCancelCost(skill) then
            self.invoked_times[skill.name] = -1
          end

          if broken then break end

          skill_available = table.filter(skills, filter_func)
        end

        if broken then break end

        player = player.next
      end until player == _target

      prev_prio = prio
      ::continue::
    end
  end

  player = _target
  repeat do
    for _, skill in ipairs(skills) do
      if skill:canRefresh(self, target, player, data) and skill.late_refresh then
        skill:refresh(self, target, player, data)
      end
    end
    player = player.next
  end until player == _target

  return broken
end

return TriggerEvent
