-- SPDX-License-Identifier: GPL-3.0-or-later

local Room = require "server.room"

--[[
local verbose = function(...)
  printf(...)
end
--]]

-- 所有当前正在运行的房间（即游戏尚未结束的房间）
---@type table<integer, Room>
local runningRooms = {}

-- 所有处于就绪态的房间，以及request协程（如果就绪的话）
---@type Room[]
local readyRooms = {}

local requestCo = coroutine.create(function(room)
  require "server.request"(room)
end)

-- 仿照Room接口编写的request协程处理器
local requestRoom = setmetatable({

  -- minDelayTime 是当没有任何就绪房间时，可以睡眠的时间。
  -- 因为这个时间是所有房间预期就绪用时的最小值，故称为minDelayTime。
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

-- 从所有运行中房间中挑出就绪的房间。
-- 方法暂时就是最简单的遍历。
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

-- 主循环。只要线程没有被杀掉，就一直循环下去。
-- 函数每轮循环会从队列中取一个元素并交给控制权，
-- 如果没有，则尝试刷新队列，无法刷新则开始睡眠。
local function mainLoop()
  -- request协程的专用特判变量。因为处理request不应当重置睡眠时长
  local rest_sleep_time

  while not requestRoom.thread:isTerminated() do
    local room = table.remove(readyRooms, 1)
    if room then
      -- verbose '============= LOOP =============='
      -- verbose('[*] Switching to %s...', tostring(room))

      RoomInstance = (room ~= requestRoom and room or nil)
      local over, rest = room:resume()
      RoomInstance = nil

      if over then
        -- verbose('[#] %s is finished, removing ...', tostring(room))
        room.logic = nil
        runningRooms[room.id] = nil
      else
        local time = requestRoom.minDelayTime
        if room == requestRoom then
          rest = rest_sleep_time
        end

        if rest and rest >= 0 then
          time = math.min((time <= 0 and 9999999 or time), rest)
        else
          time = -1
        end
        requestRoom.minDelayTime = math.ceil(time)
        -- verbose("[+] minDelay is %d ms...", requestRoom.minDelayTime)
        -- verbose('[-] %s successfully yielded, %d ready rooms left...',
        --   tostring(room), #readyRooms)
      end
    else
      refreshReadyRooms()
      if #readyRooms == 0 then
        refreshReadyRooms()
        if #readyRooms == 0 then
          local time = requestRoom.minDelayTime
          -- verbose('[.] Sleeping for %d ms...', time)
          local cur = os.getms()

          time = math.min((time <= 0 and 9999999 or time), 200)

          -- 调用RoomThread的trySleep函数开始真正的睡眠。会被wakeUp(c++)唤醒。
          requestRoom.thread:trySleep(time)

          -- verbose('[!] Waked up after %f ms...', (os.getms() - cur) / 1000)

          if time > 0 then
            rest_sleep_time = math.floor(time - (os.getms() - cur) / 1000)
          else
            rest_sleep_time = -1
          end

          requestRoom.minDelayTime = -1
        end
      end
    end
  end
  -- verbose '=========== LOOP END ============'
  -- verbose '[:)] Goodbye!'
end

-- 当Cpp侧的RoomThread运行时，以下这个函数就是这个线程的主函数。
-- 而这个函数里面又调用了上面的mainLoop。
function InitScheduler(_thread)
  requestRoom.thread = _thread
  Pcall(mainLoop)
end
