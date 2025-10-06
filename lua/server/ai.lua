---@class Base.AI : Object
---@field public room Base.RoomBase
---@field public player Base.Player
---@field public command string
---@field public data any
---@field public handler any
local AI = class("Base.AI")

function AI:initialize(player)
  ---@diagnostic disable-next-line
  self.room = RoomInstance
  self.player = player
end

function AI:__tostring()
  return string.format("%s: %s", self.class.name, tostring(self.player))
end

function AI:makeReply()
  Self = self.player -- FIXME: 这玩意还不杀？
  local now = os.getms()
  local fn = self["handle" .. self.command]
  local ret = "__cancel"
  if fn then
    local handler_class = self.room.request_handlers[self.command]
    if handler_class then
      self.handler = handler_class:new(self.player, self.data)
      self.handler:setup()
    end
    ret = fn(self, self.data)
  end
  if ret == nil or ret == "" then ret = "__cancel" end
  self.handler = nil
  verbose(1,"%s 在%.2fms后得出结果：%s", self.command, (os.getms() - now) / 1000, json.encode(ret))
  return ret
end

return AI
