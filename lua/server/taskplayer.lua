---@class TaskPlayer : Object
---@field public task Task
---@field public _splayer fk.ServerPlayer @ 对应的C++玩家
local TaskPlayer = class("TaskPlayer")

function TaskPlayer:initialize(_self, task)
  self._splayer = _self
  self.id = _self:getId()
  self.task = task
end

---@param command string
---@param data any
function TaskPlayer:doNotify(command, data)
  local cbordata = cbor.encode(data)
  self._splayer:doNotify(command, cbordata)
end

--- 全局存档
---@param key string 存档名
---@param data table
function TaskPlayer:saveGlobalState(key, data)
  if not self._splayer then return nil end
  if type(self._splayer.saveGlobalState) ~= "function" then
    fk.qWarning("self._splayer.saveGlobalState doesn't exist, Please ensure that the server version is freekill-asio 0.0.6+")
    return nil
  end
  local ok, jsonData = pcall(json.encode, data)
  if ok then
    local ret = self._splayer:saveGlobalState(key, jsonData)
    if type(ret) == "boolean" then
      coroutine.yield("__handleRequest")
    end
  else
    fk.qWarning("Failed to encode global save data: " .. jsonData)
  end
end

--- 获取全局存档
---@param key string 存档名
---@return table @ 不存在返回空表
function TaskPlayer:getGlobalSaveState(key)
  if not self._splayer then return {} end
  if type(self._splayer.getGlobalSaveState) ~= "function" then
    fk.qWarning("self._splayer.getGlobalSaveState doesn't exist, Please ensure that the server version is freekill-asio 0.0.6+")
    return {}
  end
  local data = self._splayer:getGlobalSaveState(key)
  if type(data) == "boolean" then
    data = coroutine.yield("__handleRequest")
  end
  local ok, result = pcall(json.decode, data or "{}")
  if ok then
    return result
  else
    fk.qWarning("Failed to decode global save data: " .. result)
    return {}
  end
end

return TaskPlayer
