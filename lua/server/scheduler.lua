-- SPDX-License-Identifier: GPL-3.0-or-later

Room = require "server.room"

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
    cRoom:increaseRefCount()
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
  RoomInstance = (room ~= requestRoom and room or nil)
  local over = room:resume(reason)
  RoomInstance = nil
  Self = nil -- 致敬传奇变量Self

  if over then
    for _, e in ipairs(room.logic.game_event_stack.t) do
      coroutine.close(e._co)
    end
    for _, e in ipairs(room.logic.cleaner_stack.t) do
      coroutine.close(e._co)
    end
    runningRooms[room.id] = nil
    room.room:decreaseRefCount()
    -- room = nil
    -- collectgarbage("collect")
  end
  return over
end

-- 这三个空函数是为了兼容同名Rpc方法
SetPlayerState = Util.DummyFunc
AddObserver = Util.DummyFunc
RemoveObserver = Util.DummyFunc

-- Rpc用
function GetRoom(id)
  return requestRoom:getRoom(id)
end

if FileIO.pwd():endsWith("packages/freekill-core") then
  FileIO.cd("../..")
end
