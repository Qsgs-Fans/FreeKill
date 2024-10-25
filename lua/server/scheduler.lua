-- SPDX-License-Identifier: GPL-3.0-or-later

local Room = require "server.room"

-- 所有当前正在运行的房间（即游戏尚未结束的房间）
---@type table<integer, Room>
local runningRooms = {}

-- 仿照Room接口编写的request协程处理器
local requestRoom = setmetatable({
  id = -1,
  runningRooms = runningRooms,

  getRoom = function(_, roomId)
    return runningRooms[roomId]
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

-- 当Cpp侧的RoomThread运行时，以下这个函数就是这个线程的主函数。
-- 而这个函数里面又调用了上面的mainLoop。
function InitScheduler(_thread)
  requestRoom.thread = _thread
  -- Pcall(mainLoop)
end

function IsConsoleStart()
  return requestRoom.thread:isConsoleStart()
end

local Req = require "server.request"
function HandleRequest(req)
  Req(requestRoom, req)
  return true
end

function ResumeRoom(roomId, reason)
  local room = requestRoom:getRoom(roomId)
  if not room then return false end
  if not room:isReady() then return false end
  RoomInstance = (room ~= requestRoom and room or nil)
  local over = room:resume(reason)
  RoomInstance = nil

  if over then
    for _, e in ipairs(room.logic.game_event_stack.t) do
      coroutine.close(e._co)
    end
    for _, e in ipairs(room.logic.cleaner_stack.t) do
      coroutine.close(e._co)
    end
    room.logic = nil
    runningRooms[room.id] = nil
  end
  return over
end

if FileIO.pwd():endsWith("packages/freekill-core") then
  FileIO.cd("../..")
end
