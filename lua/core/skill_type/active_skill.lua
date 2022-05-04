--- ActiveSkill is a skill type like SkillCard+ViewAsSkill in QSanguosha
---
---@class ActiveSkill : Skill
local ActiveSkill = Skill:subclass("ActiveSkill")

function ActiveSkill:initialize(name)
  Skill.initialize(self, name, Skill.NotFrequent)
end

---------
-- Note: these functions are used both client and ai
------- {

--- Determine whether the skill can be used in playing phase
---@param player Player
function ActiveSkill:canUse(player)
  return true
end

--- Determine whether a card can be selected by this skill
--- only used in skill of players
---@param to_select integer @ id of a card not selected
---@param selected integer[] @ ids of selected cards
---@param selected_targets integer[] @ ids of selected players
function ActiveSkill:cardFilter(to_select, selected, selected_targets)
  return true
end

--- Determine whether a target can be selected by this skill
--- only used in skill of players
---@param to_select integer @ id of the target
---@param selected integer[] @ ids of selected targets
---@param selected_cards integer[] @ ids of selected cards
function ActiveSkill:targetFilter(to_select, selected, selected_cards)
  return false
end

--- Determine if selected cards and targets are valid for this skill
--- If returns true, the OK button should be enabled
--- only used in skill of players
---@param selected integer[] @ ids of selected players
---@param selected_cards integer[] @ ids of selected cards
function ActiveSkill:feasible(selected, selected_cards)
  return true
end

------- }

---@param room Room
---@param cardUseEvent CardUseStruct
function ActiveSkill:onUse(room, cardUseEvent) end

---@param room Room
---@param cardEffectEvent CardEffectEvent
function ActiveSkill:onEffect(room, cardEffectEvent) end

return ActiveSkill
