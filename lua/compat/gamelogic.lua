---@class GameLogicLegacyMixin
---@field public legacy_skill_table table<(TriggerEvent|integer|string), LegacyTriggerSkill[]>
---@field public legacy_skill_priority_table table<(TriggerEvent|integer|string), number[]>
---@field public legacy_refresh_skill_table table<(TriggerEvent|integer|string), LegacyTriggerSkill[]>
---@field public legacy_skills string[]
local M = {}

---@param self GameLogic
---@param skill LegacyTriggerSkill
function M.addLegacyTriggerSkill(self, skill)
  if skill == nil or table.contains(self.legacy_skills, skill.name) then
    return
  end

  table.insert(self.legacy_skills, skill.name)

  for _, event in ipairs(skill.refresh_events) do
    if self.legacy_refresh_skill_table[event] == nil then
      self.legacy_refresh_skill_table[event] = {}
    end
    table.insert(self.legacy_refresh_skill_table[event], skill)
  end

  for _, event in ipairs(skill.events) do
    if self.legacy_skill_table[event] == nil then
      self.legacy_skill_table[event] = {}
    end
    table.insert(self.legacy_skill_table[event], skill)

    if self.legacy_skill_priority_table[event] == nil then
      self.legacy_skill_priority_table[event] = {}
    end

    local priority_tab = self.legacy_skill_priority_table[event]
    local prio = skill.priority_table[event]
    if not table.contains(priority_tab, prio) then
      for i, v in ipairs(priority_tab) do
        if v < prio then
          table.insert(priority_tab, i, prio)
          break
        end
      end

      if not table.contains(priority_tab, prio) then
        table.insert(priority_tab, prio)
      end
    end

    if not table.contains(self.legacy_skill_priority_table[event],
      skill.priority_table[event]) then

      table.insert(self.legacy_skill_priority_table[event],
        skill.priority_table[event])
    end
  end

  if skill.visible then
    if (Fk.related_skills[skill.name] == nil) then return end
    for _, s in ipairs(Fk.related_skills[skill.name]) do
      if (s.class == LegacyTriggerSkill) then
        self:addTriggerSkill(s)
      end
    end
  end
end

---@param self GameLogic
---@param event TriggerEvent|integer|string
---@param target? ServerPlayer
---@param data? any
function M.triggerForLegacy(self, event, target, data, refresh_only)
  local room = self.room
  local broken = false
  local legacy_skills = self.legacy_skill_table[event] or {}
  local skills_to_refresh = self.legacy_refresh_skill_table[event] or Util.DummyTable
  local _target = room.current -- for iteration
  local player = _target
  local cur_event = self:getCurrentEvent() or {}
  -- 如果当前事件被杀，就强制只refresh
  -- 因为被杀的事件再进行正常trigger只可能在cleaner和exit了
  refresh_only = refresh_only or cur_event.killed

  local orig_data = data
  local data_converted = false
  if data and type(data) == "table" then
    if data.toLegacy then
      data_converted = true
      data = data:toLegacy()
    elseif data[1] and data[1].toLegacy then
      -- 唉，移牌data 喜欢搞特殊
      data_converted = true
      data = table.map(data, function(v) return v:toLegacy() end)
    end
  end

  if #skills_to_refresh > 0 then repeat do
    -- refresh legacy_skills. This should not be broken
    for _, skill in ipairs(skills_to_refresh) do
      if skill:canRefresh(event, target, player, data) then
        skill:refresh(event, target, player, data)
        if data_converted then
          if orig_data.loadLegacy then
            orig_data:loadLegacy(data)
          elseif orig_data[1] and orig_data[1].loadLegacy then
            for i, single_data in ipairs(data) do
              orig_data[i]:loadLegacy(single_data)
            end
          end
        end
      end
    end
    player = player.next
  end until player == _target end

  if #legacy_skills == 0 or refresh_only then return end

  local prio_tab = self.legacy_skill_priority_table[event]
  local prev_prio = math.huge

  for _, prio in ipairs(prio_tab) do
    if broken then break end
    if prio >= prev_prio then
      -- continue
      goto trigger_loop_continue
    end

    repeat do
      local invoked_skills = {}
      local filter_func = function(skill)
        return skill.priority_table[event] == prio and
          not table.contains(invoked_skills, skill) and
          skill:triggerable(event, target, player, data)
      end

      local skill_names = table.map(table.filter(legacy_skills, filter_func), Util.NameMapper)

      while #skill_names > 0 do
        local skill_name = prio <= 0 and table.random(skill_names) or
          room:askToChoice(player, { choices = skill_names, skill_name = "trigger", prompt = "#choose-trigger" })

        local skill = Fk.skills[skill_name] --[[@as LegacyTriggerSkill]]

        table.insert(invoked_skills, skill)
        broken = skill:trigger(event, target, player, data)
        if data_converted then
          if orig_data.loadLegacy then
            orig_data:loadLegacy(data)
          elseif orig_data[1] and orig_data[1].loadLegacy then
            for i, single_data in ipairs(data) do
              orig_data[i]:loadLegacy(single_data)
            end
          end
        end
        skill_names = table.map(table.filter(legacy_skills, filter_func), Util.NameMapper)

        broken = broken or (event == fk.AskForPeaches
          and room:getPlayerById(data.who).hp > 0) or
          (table.contains({fk.PreDamage, fk.DamageCaused, fk.DamageInflicted}, event) and data.damage < 1) or
          cur_event.killed

        if broken then break end
      end

      if broken then break end

      player = player.next
    end until player == _target

    prev_prio = prio
    ::trigger_loop_continue::
  end

  return broken
end

return M
