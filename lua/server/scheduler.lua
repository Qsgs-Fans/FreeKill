-- SPDX-License-Identifier: GPL-3.0-or-later

local Room = require "server.room"

local verbose = function(...)
  -- do return end
  printf(...)
end

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
    return nil, 0
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
    return "<Request Room>"
  end,
})

runningRooms[-1] = requestRoom

local function refreshReadyRooms()
  -- verbose '[+] Refreshing ready queue...'
  for k, v in pairs(runningRooms) do
    local ready, rest = v:isReady()
    if ready then
      table.insertIfNeed(readyRooms, v)
    elseif rest and rest >= 0 then
      local time = requestRoom.minDelayTime
      time = math.min((time <= 0 and 9999999 or time), rest)
      requestRoom.minDelayTime = math.ceil(time)
    end
  end
  -- verbose('[+] now have %d ready rooms...', #readyRooms)
end

local function mainLoop()
  while not requestRoom.thread:isTerminated() do
    local room = table.remove(readyRooms, 1)
    if room then
      verbose '============= LOOP =============='
      verbose('[*] Switching to %s...', tostring(room))

      RoomInstance = (room ~= requestRoom and room or nil)
      local over, rest = room:resume()
      RoomInstance = nil

      if over then
        verbose('[#] %s is finished, removing ...', tostring(room))
        runningRooms[room.id] = nil
      else
        local time = requestRoom.minDelayTime
        if rest and rest >= 0 then
          time = math.min((time <= 0 and 9999999 or time), rest)
        else
          time = -1
        end
        requestRoom.minDelayTime = math.ceil(time)
        -- verbose("[+] minDelay is %d ms...", requestRoom.minDelayTime)
        verbose('[-] %s successfully yielded, %d ready rooms left...',
          tostring(room), #readyRooms)
      end
    else
      refreshReadyRooms()
      if #readyRooms == 0 then
        refreshReadyRooms()
        if #readyRooms == 0 then
          local time = requestRoom.minDelayTime
          verbose('[.] Sleeping for %d ms...', time)
          local cur = os.getms()
          requestRoom.thread:trySleep(time)
          verbose('[!] Waked up after %f ms...', (os.getms() - cur) / 1000)
          requestRoom.minDelayTime = -1
        end
      end
    end
  end
  verbose '=========== LOOP END ============'
  verbose '[:)] Goodbye!'
end

function InitScheduler(_thread)
  requestRoom.thread = _thread
  xpcall(mainLoop, debug.traceback)
end
