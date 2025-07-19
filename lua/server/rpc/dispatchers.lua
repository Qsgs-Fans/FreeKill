-- RPC过程处理
-- 所有函数都是先返回一个布尔再返回真实值
-- 基本上都是三步走，验证参数 - pcall - 返回success与返回值

-- 不得不品的ping，便于测试
local ping = function()
  return true, "PONG"
end

local bye = function()
  fk._rpc_finished = true
  return true, "Goodbye"
end

-- 以下是目前多进程方案中真正用到过的

local resumeRoom = function(params)
  if type(params[1]) ~= "number" then
    return false, nil
  end

  local ok, ret = pcall(ResumeRoom, params[1], params[2])
  if not ok then return false, 'internal_error' end
  return true, ret
end

local handleRequest = function(params)
  if type(params[1]) ~= "string" then
    return false, nil
  end

  local ok, ret = pcall(HandleRequest, params[1])
  if not ok then return false, 'internal_error' end
  return true, ret
end

local setPlayerState = function(params)
  if not (type(params[1]) == "number" and type(params[2]) == "number" and type(params[3] == "number")) then
    return false, nil
  end

  local roomId = params[1]
  local playerId = params[2]
  local newState = params[3]

  local room = GetRoom(roomId)
  if not room then
    return false, "Room not found"
  end

  for _, p in ipairs(room.room:getPlayers()) do
    if p.id == playerId then
      p.state = newState
      return true, nil
    end
  end

  return false, "Player not found"
end

local addObserver = function(params)
  if not (type(params[1]) == "number" and type(params[2]) == "table") then
    return false, nil
  end

  local roomId = params[1]
  local obj = params[2]

  local room = GetRoom(roomId)
  if not room then
    return false, "Room not found"
  end

  table.insert(room.room:getObservers(), fk.ServerPlayer(obj))
  return true, nil
end

local removeObserver = function(params)
  if not (type(params[1]) == "number" and type(params[2]) == "number") then
    return false, nil
  end

  local roomId = params[1]
  local playerId = params[2]

  local room = GetRoom(roomId)
  if not room then
    return false, "Room not found"
  end

  local observers = room.room:getObservers()
  for i, p in ipairs(observers) do
    if p.id == playerId then
      table.remove(observers, i)
      return true, nil
    end
  end

  return false, "Player not found"
end

---@type table<string, fun(...): boolean, ...>
return {
  ping = ping,
  bye = bye,

  ResumeRoom = resumeRoom,
  HandleRequest = handleRequest,

  SetPlayerState = setPlayerState,
  AddObserver = addObserver,
  RemoveObserver = removeObserver,
}
