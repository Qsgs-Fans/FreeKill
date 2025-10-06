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

require "lunarltk.core.events.misc"
require "lunarltk.core.events.hp"
require "lunarltk.core.events.death"
require "lunarltk.core.events.movecard"
require "lunarltk.core.events.usecard"
require "lunarltk.core.events.skill"
require "lunarltk.core.events.judge"
require "lunarltk.core.events.gameflow"
require "lunarltk.core.events.pindian"
