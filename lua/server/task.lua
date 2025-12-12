---@class Task: Object
---@field id integer
---@field co any
---@field type string
---@field data string
---@field player TaskPlayer?
---@field cServer any
---@field cTask any
local Task = class("Task")

local TaskPlayer = require "server.taskplayer"

function Task:initialize(cServer, cTask)
  self.cServer = cServer
  self.cTask = cTask

  self.id = cTask:getId()
  self.type = cTask:getTaskType()
  local ok, data = pcall(cbor.decode, cTask:getData())
  if ok then
    self.data = data
  else
    fk.qWarning("cbor decode error on task initialization: " .. cTask:getData())
  end
  local p = cTask:getPlayer()
  if p then
    self.player = TaskPlayer:new(p, self)
  end
end

-- 和Room:resume如出一辙 反正是管理协程
function Task:resume(reason)
  if not self.co then
    local def = Fk:getTaskDef(self.type)
    local handler
    if def then
      handler = def.handler
    else
      fk.qWarning(string.format("Task of type '%s' not found, won't do anything!", self.type))
      handler = Util.DummyFunc
    end
    self.co = coroutine.create(function()
      handler(self)
    end)
  end

  local main_co = self.co

  if reason == "abort" then
    goto FIN
  end

  do
    local ret, err_msg, rest_time = coroutine.resume(main_co, reason)

    -- handle error
    if ret == false then
      fk.qCritical(err_msg .. "\n" .. debug.traceback(main_co))
      goto FIN
    end

    if rest_time == "over" then
      goto FIN
    end

    if coroutine.status(main_co) == "dead" then
      goto FIN
    end

    return false, rest_time
  end

  ::FIN::
  return true
end

--- 延迟一段时间。
---@param ms integer @ 要延迟的毫秒数
function Task:delay(ms)
  self.cTask:delay(math.ceil(ms))
  coroutine.yield("__handleRequest", ms)
end

--- 全局存档
---@param key string 存档名
---@param data table
function Task:saveGlobalState(key, data)
  local ok, jsonData = pcall(json.encode, data)
  if ok then
    local ret = self.cTask:saveGlobalState(key, jsonData)
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
function Task:getGlobalSaveState(key)
  local data = self.cTask:getGlobalSaveState(key)
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

return Task
