---@class GameMode: Object
---@field public name string
---@field public minPlayer integer
---@field public maxPlayer integer
---@field public rule TriggerSkill
---@field public logic fun()
local GameMode = class("GameMode")

function GameMode:initialize(name, min, max)
  self.name = name
  self.minPlayer = math.max(min, 2)
  self.maxPlayer = math.min(max, 8)
end

return GameMode
