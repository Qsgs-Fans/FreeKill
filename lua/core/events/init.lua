---@class TriggerData: Object
---@field private _data any
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

require "core.events.misc"
require "core.events.hp"
require "core.events.death"
require "core.events.movecard"
require "core.events.usecard"
require "core.events.skill"
require "core.events.judge"
require "core.events.gameflow"
require "core.events.pindian"

-- 要兼容的嘛
require "compat.events.init"
