---@class TriggerData: Object
---@field private _data any
---@field public extra_data any
TriggerData = class("TriggerData")

function TriggerData:initialize(spec)
  -- table.assign(self, spec)
  self._data = spec
end

function TriggerData:__index(k)
  if k == "_data" then return rawget(self, k) end
  return self._data[k]
end

function TriggerData:__newindex(k, v)
  if k == "_data" then return rawset(self, k, v) end
  if not self._data then return rawset(self, k, v) end
  self._data[k] = v
end

require "ltk.core.events.misc"
require "ltk.core.events.hp"
require "ltk.core.events.death"
require "ltk.core.events.movecard"
require "ltk.core.events.usecard"
require "ltk.core.events.skill"
require "ltk.core.events.judge"
require "ltk.core.events.gameflow"
require "ltk.core.events.pindian"
