---@class ClientPlayer: Player
---@field player fk.Player
---@field known_cards integer[]
---@field global_known_cards integer[]
local ClientPlayer = Player:subclass("ClientPlayer")

function ClientPlayer:initialize(cp)
  Player.initialize(self)
  self.id = cp:getId()
  self.player = cp
  self.known_cards = {}   -- you know he/she have this card, but not shown
  self.global_known_cards = {}  -- card that visible to all players
end

---@param skill Skill
function ClientPlayer:hasSkill(skill)
  return table.contains(self.player_skills, skill)
end

---@param skill Skill
function ClientPlayer:addSkill(skill)
  table.insert(self.player_skills, skill)
end

---@param skill Skill
function ClientPlayer:loseSkill(skill)
  table.removeOne(self.player_skills, skill)
end

return ClientPlayer
