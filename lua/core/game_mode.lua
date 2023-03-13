---@class GameMode: Object
---@field name string
---@field minPlayer integer
---@field maxPlayer integer
---@field rule TriggerSkill
---@field logic GameLogic
local GameMode = class("GameMode")

function GameMode:initialize(name, min, max)
  self.name = name
  self.minPlayer = math.min(min, 2)
  self.maxPlayer = math.min(max, 2)
end

return GameMode
