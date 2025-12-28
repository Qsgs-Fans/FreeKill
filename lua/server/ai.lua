---@class Base.AI : Object
---@field public room Base.RoomBase
---@field public player Base.Player
---@field public command string
---@field public data any
---@field public handler any
---@field public _debug boolean?
local AI = class("Base.AI")

function AI:initialize(player)
  ---@diagnostic disable-next-line
  self.room = RoomInstance
  self.player = player

  -- 直接用verbose结合verbose_level不是个好办法
  -- 因为lua会先计算参数再调用函数，在不启用verbose的情况下
  -- 那些调试用的json.encode就变成纯累赘了
  --
  -- 当然verbose本身能显示cpu时间是很不错的，只是需要结合if判断才能避免浪费
  -- 如果有C++的宏那就好了
  --
  -- 总之开发底层ai时设为true就可以了
  --
  -- [!!] 提交到master的话这个务必设为false!
  self._debug = false
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

  if self._debug then
    verbose(1, "%s 在%.2fms后得出结果：%s", self.command, (os.getms() - now) / 1000, json.encode(ret))
  end
  return ret
end

return AI
