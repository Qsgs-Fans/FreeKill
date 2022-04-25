local ActiveCardSkill = Skill:subclass("ActiveCardSkill")

function ActiveCardSkill:initialize(name)
  Skill.initialize(self, name, Skill.Frequent)
end

---@param room Room
---@param cardUseEvent CardUseStruct
function ActiveCardSkill:onUse(room, cardUseEvent) end

---@param room Room
---@param cardEffectEvent CardEffectEvent
function ActiveCardSkill:onEffect(room, cardEffectEvent) end

return ActiveCardSkill
