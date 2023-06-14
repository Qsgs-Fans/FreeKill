-- SPDX-License-Identifier: GPL-3.0-or-later

local Room = require "server.room"

-- C++的RoomThread实例。利用它与C++代码交互。
local roomThread

-- 所有当前正在运行的房间（即游戏尚未结束的房间）
---@type Room[]
local runningRooms = {}

-- 所有处于就绪态的房间，以及request协程（如果就绪的话）
---@type Room[]
local readyRooms = {}

-- 距离下个房间就绪的最短等待时间，为-1表示不确定。
local minDelayTime = -1

local requestCo = coroutine.create(function(room)
  require "server.request"(room)
end)

-- 仿照Room接口编写的request协程处理器
local requestRoom = setmetatable({
  getRoom = function(_, roomId)
    return runningRooms[roomId]
  end,
  resume = function(self)
    local err, msg = coroutine.resume(requestCo, self)
    if err == false then
      fk.qCritical(msg)
      print(debug.traceback(requestCo))
    end
  end,
  isReady = function()
    return roomThread:hasRequest()
  end,
  registerRoom = function(_, id)
    local cRoom = roomThread:getRoom(id)
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
      table.insert(readyRooms, v)
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
      local over = room:resume()
      if over then
        runningRooms[room.id] = nil
      end
    else
      refreshReadyRooms()
      if #readyRooms == 0 then
        refreshReadyRooms()
        if #readyRooms == 0 then
          print 'sleep ...'
          roomThread:trySleep(minDelayTime)
          print 'wake up ...'
        end
      end
    end
  end
end

function InitScheduler(_thread)
  roomThread = _thread
  requestRoom.thread = _thread
  mainLoop()
end
