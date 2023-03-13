---@class Scenario: Object
---@field name string
---@field minPlayer integer
---@field maxPlayer integer
---@field rule TriggerSkill
---@field logic GameLogic
local Scenario = class("Scenario")

function Scenario:initialize(name, min, max)
  self.name = name
  self.minPlayer = math.min(min, 2)
  self.maxPlayer = math.min(max, 2)
end

return Scenario
