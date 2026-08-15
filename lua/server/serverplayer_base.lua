--- 各种ServerPlayer的第二基类
---@class ServerPlayerBase : Base.Player
---@field public serverplayer fk.ServerPlayer @ 控制者对应的C++玩家
---@field public _splayer fk.ServerPlayer @ 对应的C++玩家
---@field public room ServerRoomBase
---@field public _timewaste_count integer @连续烧绳时间，单位为秒
---@field public ai Base.AI
local ServerPlayerBase = {}

function ServerPlayerBase:initialize(_self)
  self.serverplayer = _self -- 控制者
  self._splayer = _self -- 真正在玩的玩家
  self._observers = { _self } -- "旁观"中的玩家，然而不包括真正的旁观者
  self.id = _self:getId()

  self._timewaste_count = 0
end

---@param command string
---@param data any
function ServerPlayerBase:doNotify(command, data)
  local cbordata = cbor.encode(data)

  local room = self.room
  for _, p in ipairs(self._observers) do
    if p:getState() ~= fk.Player_Robot then
      room.notify_count = room.notify_count + 1
      p:doNotify(command, cbordata)
    end
  end

  for _, t in ipairs(room.observers) do
    local id, p = table.unpack(t)
    if id == self.id and room.room:hasObserver(p) and p:getState() ~= fk.Player_Robot then
      p:doNotify(command, cbordata)
    end
  end

  if room.notify_count >= room.notify_max and
    coroutine.status(room.main_co) == "normal" then
    room:delay(100)
  end
end

--- 发送一句聊天
---@param msg string
function ServerPlayerBase:chat(msg)
  self.room:doBroadcastNotify("Chat", {
    type = 2,
    sender = self.id,
    msg = msg,
  })
end

function ServerPlayerBase:reconnect()
  local room = self.room

  local sp = self._splayer
  local summary = room:serialize(self)

  -- 可能断线时在别人视角思考；先找到正在思考的视角
  local thinker = table.find(room.players, function(p)
    return table.contains(p._observers, sp)
  end)
  ---@cast thinker -nil

  -- 然后将视角设为自己 因为刚刚重连嘛
  table.removeOne(thinker._observers, sp)
  table.insert(self._observers, sp)

  -- 至此方可正常用doNotify
  self:doNotify("Reconnect", summary)
  self:doNotify("RoomOwner", { room.room:getOwner():getId() })

  room:broadcastProperty(self, "state")

  -- 如果是直接顶号的话，部分情况Request会继续执行但是客户端没有交互信息
  -- 所以如果有这种情况的话，再发送一次给重连的玩家
  local req = room.current_request
  if req and table.contains(req.players, thinker) and
    sp:thinking() and not req.result[thinker.id] then

    sp:setThinking(false)
    req:_sendPacket(thinker)
  end
end

function ServerPlayerBase:serialize()
  local klass = self.class.super --[[@as Base.Player]]
  local o = klass.serialize(self)
  local sp = self._splayer
  o.setup_data = {
    self.id,
    sp:getScreenName(),
    sp:getAvatar(),
    false,
    sp:getTotalGameTime(),
  }
  return o
end

--- 保存当前游戏模式的玩家存档
---@param data table
function ServerPlayerBase:saveState(data)
  if not self._splayer then return nil end
  if type(self._splayer.saveState) ~= "function" then
    fk.qWarning("self._splayer.saveState doesn't exist, Please ensure that the server version is freekill-asio 0.0.5+")
    return nil
  end
  local ok, jsonData = pcall(json.encode, data)
  if ok then
    local ret = self._splayer:saveState(jsonData)
    if type(ret) == "boolean" then
      self.room:yield(function(r) return r == "query_done" end)
    end
  else
    fk.qWarning("Failed to encode save data: " .. jsonData)
  end
end

--- 获取当前游戏模式的玩家存档
---@return table @ 不存在返回空表
function ServerPlayerBase:getSaveState()
  if not self._splayer then return {} end
  if type(self._splayer.getSaveState) ~= "function" then
    fk.qWarning("self._splayer.getSaveState doesn't exist, Please ensure that the server version is freekill-asio 0.0.5+")
    return {}
  end
  local data = self._splayer:getSaveState()
  if type(data) == "boolean" then
    data = self.room:yield(function(reason)
      local ok = pcall(json.decode, reason)
      return ok
    end)
  end
  local ok, result = pcall(json.decode, data or "{}")
  if ok then
    return result
  else
    fk.qWarning("Failed to decode save data: " .. result)
    return {}
  end
end

--- 全局存档
---@param key string 存档名
---@param data table
function ServerPlayerBase:saveGlobalState(key, data)
  if not self._splayer then return nil end
  if type(self._splayer.saveGlobalState) ~= "function" then
    fk.qWarning("self._splayer.saveGlobalState doesn't exist, Please ensure that the server version is freekill-asio 0.0.6+")
    return nil
  end
  local ok, jsonData = pcall(json.encode, data)
  if ok then
    local ret = self._splayer:saveGlobalState(key, jsonData)
    if type(ret) == "boolean" then
      self.room:yield(function(r) return r == "query_done" end)
    end
  else
    fk.qWarning("Failed to encode global save data: " .. jsonData)
  end
end

--- 获取全局存档
---@param key string 存档名
---@return table @ 不存在返回空表
function ServerPlayerBase:getGlobalSaveState(key)
  if not self._splayer then return {} end
  if type(self._splayer.getGlobalSaveState) ~= "function" then
    fk.qWarning("self._splayer.getGlobalSaveState doesn't exist, Please ensure that the server version is freekill-asio 0.0.6+")
    return {}
  end
  local data = self._splayer:getGlobalSaveState(key)
  if type(data) == "boolean" then
    data = self.room:yield(function(reason)
      local ok = pcall(json.decode, reason)
      return ok
    end)
  end
  local ok, result = pcall(json.decode, data or "{}")
  if ok then
    return result
  else
    fk.qWarning("Failed to decode global save data: " .. result)
    return {}
  end
end

return ServerPlayerBase
