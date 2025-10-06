---@class ClientPlayerBase: Base.Player
---@field public player fk.Player
---@field public ready boolean
---@field public owner boolean
local ClientPlayerBase = {}

function ClientPlayerBase:initialize(cp)
  self.player = cp
  self.id = cp:getId()

  self.ready = false
  self.owner = false
end

function ClientPlayerBase:serialize()
  local klass = self.class.super --[[@as Base.Player]]
  local o = klass.serialize(self)
  local sp = self.player
  o.setup_data = {
    self.id,
    sp:getScreenName(),
    sp:getAvatar(),
    false,
    sp:getTotalGameTime(),
  }
  o.ready = self.ready
  o.owner = self.owner
  return o
end

return ClientPlayerBase
