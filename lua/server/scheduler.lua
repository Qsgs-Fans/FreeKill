-- SPDX-License-Identifier: GPL-3.0-or-later

Request = require "server.request"
GameEvent = require "server.gameevent"
GameLogic = require "lunarltk.server.gamelogic"
ServerPlayer = require "lunarltk.server.serverplayer"
Room = require "lunarltk.server.room"

for _, l in ipairs(Fk._custom_events) do
  local name, p, m, c, e = l.name, l.p, l.m, l.c, l.e
  -- GameEvent.prepare_funcs[name] = p
  -- GameEvent.functions[name] = m
  -- GameEvent.cleaners[name] = c
  -- GameEvent.exit_funcs[name] = e
  local custom = GameEvent:subclass(name)
  custom.prepare = p
  custom.main = m
  custom.clear = c
  custom.exit = e
  GameEvent[name] = custom
end

---@type Player
Self = nil -- `Self' is client-only, but we need it in AI
dofile "lua/lunarltk/server/ai/init.lua"

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
    local cRoom = self.thread:getRoom(id) ---@type fk.Room

    local gameMode
    local ok, settings = pcall(cbor.decode, cRoom:settings())
    if ok then
      gameMode = settings.gameMode
    end

    local room_klass = Fk:getBoardGame(gameMode).room_klass
    local room = room_klass:new(cRoom)
    cRoom:increaseRefCount() -- FIXME: 这行理应不需要了 但是Qt版服务端还依赖着
    runningRooms[room.id] = room
  end,

  callbacks = {
    ["newroom"] = function(s, id)
      s:registerRoom(id)
      ResumeRoom(id)
    end,
  }
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

function HandleRequest(req)
  local reqlist = req:split(",")
  local roomId = tonumber(table.remove(reqlist, 1))
  local room = requestRoom:getRoom(roomId)

  if room then
    RoomInstance = room
    local id = tonumber(reqlist[1])
    local command = reqlist[2]
    local fn = room.callbacks[command] or Util.DummyFunc
    Pcall(fn, room, id, reqlist)
    RoomInstance = nil
  end

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
