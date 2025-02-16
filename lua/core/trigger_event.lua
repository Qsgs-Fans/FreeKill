---@class TriggerEvent: Object
---@field public id integer
---@field public room Room
---@field public target ServerPlayer?
---@field public data any 具体的触发时机会继承这个类 进而获得具体的data类型
---@field public skill_data table<string, table<string, any>>
---  某个技能在这个event范围内的数据，比如costData之类的
---@field public finished_skills string[] 已经发动完了的技能 不会再进行检测
---@field public refresh_only boolean? 这次triggerEvent是不是仅执行refresh
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
  local name = (skill.main_skill and skill.main_skill or skill).name
  self.skill_data[name] = self.skill_data[name] or {}
  self.skill_data[name][k] = v
end

---@param skill Skill
---@param k string
function TriggerEvent:getSkillData(skill, k)
  local name = (skill.main_skill and skill.main_skill or skill).name
  return self.skill_data[name][k]
end

---@param skill Skill
function TriggerEvent:setCostData(skill, v)
  self:setSkillData(skill, "cost_data", v)
end

---@param skill Skill
function TriggerEvent:getCostData(skill)
  return self:getSkillData(skill, "cost_data")
end

-- 先执行带refresh的，再执行带效果的
function TriggerEvent:exec()
  local room, logic = self.room, self.room.logic
  local skills = logic.skill_table[self.class] or Util.DummyTable
  if #skills == 0 then return false end

  local _target = room.current -- for iteration
  local player = _target
  local event = self.class
  local target = self.target
  local data = self.data
  local cur_event = logic:getCurrentEvent() or Util.DummyTable
  -- 如果当前事件被杀，就强制只refresh
  -- 因为被杀的事件再进行正常trigger只可能在cleaner和exit了
  self.refresh_only = self.refresh_only or cur_event.killed

  if self.refresh_only then return end

  repeat do
    -- refresh skills. This should not be broken
    for _, skill in ipairs(skills) do
      if skill:canRefresh(self, target, player, data) then
        skill:refresh(self, target, player, data)
      end
    end
    player = player.next
  end until player == _target

  local broken

  local prio_tab = logic.skill_priority_table[event]
  local prev_prio = math.huge

  for _, prio in ipairs(prio_tab) do
    if broken then break end
    if prio >= prev_prio then
      goto continue
    end

    repeat do
      local invoked_skills = {}
      ---@param skill TriggerSkill
      local filter_func = function(skill)
        return skill.priority == prio and
          not table.contains(invoked_skills, skill) and
          skill:triggerable(self, target, player, data)
      end

      local skill_names = table.map(table.filter(skills, filter_func), Util.NameMapper)

      while #skill_names > 0 do
        local skill_name = prio <= 0 and table.random(skill_names) or
          room:askToChoice(player, { choices = skill_names, skill_name = "trigger", prompt = "#choose-trigger" })

        local skill = Fk.skills[skill_name]
        ---@cast skill TriggerSkill

        table.insert(invoked_skills, skill)
        broken = skill:trigger(self, target, player, data)
        skill_names = table.map(table.filter(skills, filter_func), Util.NameMapper)

        -- TODO: 这段开个方法，搬家到相关时机的某个方法内
        broken = broken or (event == fk.AskForPeaches
          and data.who.hp > 0) or
          (table.contains({fk.PreDamage, fk.DamageCaused, fk.DamageInflicted}, event) and data.damage < 1) or
          cur_event.killed

        if broken then break end
      end

      if broken then break end

      player = player.next
    end until player == _target

    prev_prio = prio
    ::continue::
  end

  return broken
end

return TriggerEvent
