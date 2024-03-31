-- 仿效 swig 中 class ServerPlayer 的接口制作，为了便于测试

local ServerPlayer = class("fk.ServerPlayer")

fk.Player_Invalid = 0
fk.Player_Online = 1
fk.Player_Trust = 2
fk.Player_Run = 3
fk.Player_Leave = 4
fk.Player_Robot = 5
fk.Player_Offline = 6

local _id = 1
function ServerPlayer:initialize()
  self.id = _id
  self.screenName = "player" .. _id
  self.state = fk.Player_Online
  self.died = false
  self._busy = false
  self._thinking = false
  _id = _id + 1
end

function ServerPlayer:getId() return self.id end
function ServerPlayer:setId(id) self.id = id end
function ServerPlayer:getScreenName() return self.screenName end
function ServerPlayer:getAvatar() return "zhouyu" end
function ServerPlayer:getState() return self.state end
function ServerPlayer:setState(state) self.state = state end
function ServerPlayer:isDied() return self.died end
function ServerPlayer:setDied(died) self.died = died end

function ServerPlayer:doRequest(...) if self.id == 1 then print(...) end end
function ServerPlayer:waitForReply() return "__cancel" end
function ServerPlayer:doNotify(...) if self.id == 1 then print(...) end end
function ServerPlayer:busy() return self._busy end
function ServerPlayer:setBusy(b) self._busy = b end
function ServerPlayer:thinking() return self._thinking end
function ServerPlayer:setThinking(t) self._thinking = t end
function ServerPlayer:emitKick()
  self.state = fk.Player_Offline
end

return ServerPlayer

