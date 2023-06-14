-- SPDX-License-Identifier: GPL-3.0-or-later

local Room = require "server.room"

-- 所有当前正在运行的房间（即游戏尚未结束的房间）
---@type Room[]
local runningRooms = {}

-- 所有处于就绪态的房间，以及request协程（如果就绪的话）
---@type Room[]
local readyRooms = {}

local requestCo = coroutine.create(function(room)
  require "server.request"(room)
end)

-- 仿照Room接口编写的request协程处理器
local requestRoom = setmetatable({
  minDelayTime = -1,
  getRoom = function(_, roomId)
    return runningRooms[roomId]
  end,
  resume = function(self)
    local err, msg = coroutine.resume(requestCo, self)
    if err == false then
      fk.qCritical(msg)
      print(debug.traceback(requestCo))
    end
    return nil, nil
  end,
  isReady = function(self)
    return self.thread:hasRequest()
  end,
  registerRoom = function(self, id)
    local cRoom = self.thread:getRoom(id)
    local room = Room:new(cRoom)
    runningRooms[room.id] = room
  end,
}, {
  __tostring = function()
    return "<Request handling Room>"
  end,
})

runningRooms[-1] = requestRoom

local function refreshReadyRooms()
  for k, v in pairs(runningRooms) do
    if v:isReady() then
      table.insertIfNeed(readyRooms, v)
    end
  end
  printf('now have %d ready rooms...', #readyRooms)
end

local function mainLoop()
  while true do
    local room = table.remove(readyRooms, 1)
    if room then
      printf('switching to room %s...', tostring(room))
      RoomInstance = (room ~= requestRoom and room or nil)
      local over, rest = room:resume()
      if over then
        runningRooms[room.id] = nil
      end
      local time = requestRoom.minDelayTime
      if rest then
        time = math.min((time == -1 and 9999999 or time), rest)
      else
        time = -1
      end
      requestRoom.minDelayTime = math.floor(time)
      printf("minDelay is %d ms...", requestRoom.minDelayTime)
    else
      refreshReadyRooms()
      if #readyRooms == 0 then
        refreshReadyRooms()
        if #readyRooms == 0 then
          local time = requestRoom.minDelayTime
          printf('sleep for %f ms...', time)
          requestRoom.thread:trySleep(time)
          print 'wake up ...'
        end
      end
    end
  end
end

function InitScheduler(_thread)
  requestRoom.thread = _thread
  mainLoop()
end
