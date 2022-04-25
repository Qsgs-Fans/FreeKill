---@class SkillCard : Card
local SkillCard = Card:subclass("SkillCard")

function SkillCard:initialize(name)
  Card.initialize(self, name, Card.NoSuit, 0)
  self.type = Card.TypeSkill
end

return SkillCard
