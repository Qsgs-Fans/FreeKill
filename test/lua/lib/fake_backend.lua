local consoleUI = require 'ui'

if UsingNewCore then FileIO.cd("packages/freekill-core") end
fk.Player = require 'lsp.player'
local tmp = require 'lsp.server'
fk.Room, fk.ServerPlayer = tmp[1], tmp[2]
fk.Client = require 'lsp.client'

FkTest = {}

dofile 'lua/lsp/test_util.lua'
dofile 'lua/client/client.lua'

if UsingNewCore then FileIO.cd("packages/freekill-core") end
dofile 'lua/server/scheduler.lua'

dofile 'test/lua/testmode.lua'

function FkTest.createFakeQList(arr)
  return setmetatable(arr, {
    __index = {
      at = function(self, i)
        return self[i+1]
      end,
      length = function(self)
        return #self
      end,
    }
  })
end

---@param id integer
---@param name string?
---@param avatar string?
---@return fk.Player
function FkTest.createFakePlayer(id, name, avatar)
  local ret = setmetatable({}, { __index = fk.ServerPlayer })
  ret:setId(id)
  ret:setScreenName(name or ("test_player_" .. id))
  ret:setAvatar(avatar or "guojia")
  ret:setState(id > 0 and fk.Player_Online or fk.Player_Robot)
  ret:setDied(false)
  ret:setThinking(false)
  ret:setGameData(0, 0, 0)
  return ret
end

function FkTest.createFakeClient()
  local p = FkTest.createFakePlayer(1)
  return setmetatable({
    _self = p,
    players = { [1] = p },
    _reply_list = {},
    _ui = consoleUI,
  }, { __index = fk.Client })
end

---@param idlist integer[]
---@return fk.Room
function FkTest.createFakeRoom(idlist)
  local players = {}
  for _, id in ipairs(idlist) do
    table.insert(players, FkTest.createFakePlayer(id))
  end
  local ret = setmetatable({
    id = 1,
    players = FkTest.createFakeQList(players),
    owner = players[1],
    observers = FkTest.createFakeQList{},
    timeout = 15,
    _settings = cbor.encode {
      enableFreeAssign = false,
      enableDeputy = false,
      gameMode = "testmode",
      disabledPack = {},
      generalNum = 3,
      luckTime = 0,
      password = "",
      disabledGenerals = {},
    },
  }, { __index = fk.Room })

  return ret
end

function FkTest.createFakeCppBackend()
  local cClient = FkTest.createFakeClient()
  local idlist = {1, 2, 3, 4, 5, 6, 7, 8}
  local cRoom = FkTest.createFakeRoom(idlist)
  local sp = cRoom:getOwner()
  sp._fake_router = cClient

  -- 以下代码全部忠于cpp原作
  CreateLuaClient(cClient)
  Self = ClientPlayer:new(cClient:getSelf())
  ClientSelf = Self

  -- 模拟Room::addPlayer
  -- updateGameData就算了 没啥用
  sp:doNotify("EnterRoom", cbor.encode { 8, 15, cbor.decode(cRoom:settings()) })
  local plist = cRoom:getPlayers()
  for i = 1, 7 do
    local p = plist:at(i)
    sp:doNotify("AddPlayer", cbor.encode {
      p:getId(),
      p:getScreenName();
      p:getAvatar();
      true,
      0,
    })
  end
  sp:doNotify("RoomOwner", cbor.encode {1})

  -- 如此如此 就有了一个已经加入房间的client了 在全局变量ClientInstance
  -- 返回创建的room备用
  return cRoom
end

local cRoom = FkTest.createFakeCppBackend()

---@type Room
FkTest.room = nil

function FkTest.initRoom()
  FkTest.room = Room:new(cRoom)
  FkTest.room._test_disable_delay = true
  RoomInstance = FkTest.room
  FkTest.room:resume("request_timer")
  RoomInstance = nil

  for _, p in ipairs(FkTest.room.players) do
    FkTest.cleanNextReplies(p)
  end
end

--- 设置player接下来数次收到Request时应当做出的回复
---
--- 注意了，replies不会自动清空的，必须有相应次数的request次数才行
---@param p ServerPlayer
---@param replies any[]
function FkTest.setNextReplies(p, replies)
  p.serverplayer._fake_router = p._fake_router or { _reply_list = {} }
  for _, v in ipairs(replies) do
    table.insert(p.serverplayer._fake_router._reply_list, cbor.encode(v))
  end
end

--- 清空player应做出的回复
---@param p ServerPlayer
function FkTest.cleanNextReplies(p)
  local router = p.serverplayer._fake_router or {}
  router._reply_list = {}
  p.serverplayer._fake_router = router
end

--- 在房间设置断点，当player遇到对应command且data符合条件的情况时，房间就会进入断点状态
---
--- 在断点状态中，可以针对Client编写一些测试代码并通过runInClient运行
---@param p ServerPlayer
---@param command string
---@param filter_func? fun(any): boolean?
function FkTest.setRoomBreakpoint(p, command, filter_func)
  local room = FkTest.room
  local breakpoints = room:getTag("__test_breakpoints") or {}
  table.insert(breakpoints, { p, command, filter_func or Util.TrueFunc })
  room:setTag("__test_breakpoints", breakpoints)
end

--- 在房间内运行一段代码。房间必须不处于断点状态，否则不负责
---
--- 可以执行游戏事件等，也会令Fk:currentRoom返回Room实例
---@param fn? fun()
function FkTest.runInRoom(fn)
  RoomInstance = FkTest.room
  FkTest.room:resume(fn)
  RoomInstance = nil
end

--- 唤起处于断点状态的房间
function FkTest.resumeRoom()
  FkTest.runInRoom()
end

--- 在客户端角度运行代码（Fk:currentRoom返回Client实例；可以使用Self）
function FkTest.runInClient(fn)
  local room = RoomInstance
  RoomInstance = nil
  local s = Self
  Self = ClientSelf
  fn()
  Self = s
  RoomInstance = room
end

function FkTest.clearRoom()
  if not FkTest.room.game_finished then FkTest.room:gameOver("") end
  -- 客户端需要模拟一次返回房间来清掉数据
  ClientInstance:initialize(ClientInstance.client)
  Self = ClientPlayer:new(ClientInstance.client:getSelf())
  ClientSelf = Self
  ClientInstance.players = {Self}
  ClientInstance.alive_players = {Self}

  local plist = cRoom:getPlayers()
  local sp = cRoom:getOwner()
  for i = 1, 7 do
    local p = plist:at(i)
    sp:doNotify("AddPlayer", cbor.encode {
      p:getId(),
      p:getScreenName();
      p:getAvatar();
      true,
      0,
    })
  end
end
