local consoleUI = require 'ui'

if UsingNewCore then FileIO.cd("packages/freekill-core") end
Room = require 'lua.server.room'
fk.Player = require 'lua.lsp.player'
local tmp = require 'lua.lsp.server'
fk.Room, fk.ServerPlayer = tmp[1], tmp[2]
fk.Client = require 'lua.lsp.client'
dofile 'lua/client/client.lua'

dofile 'test/lua/testmode.lua'

FkTest = {}

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
    _settings = json.encode {
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
  sp:doNotify("EnterRoom", json.encode{ 8, 15, json.decode(cRoom:settings()) })
  local plist = cRoom:getPlayers()
  for i = 1, 7 do
    local p = plist:at(i)
    sp:doNotify("AddPlayer", json.encode{
      p:getId(),
      p:getScreenName();
      p:getAvatar();
      true,
      0,
    })
  end
  sp:doNotify("RoomOwner", json.encode{1})

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
end

function FkTest.setNextReplies(p, replies)
  p.serverplayer._fake_router = p._fake_router or { _reply_list = {} }
  table.insertTable(p.serverplayer._fake_router._reply_list, replies)
end

function FkTest.runInRoom(fn)
  RoomInstance = FkTest.room
  FkTest.room:resume(fn)
  RoomInstance = nil
end

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
    sp:doNotify("AddPlayer", json.encode{
      p:getId(),
      p:getScreenName();
      p:getAvatar();
      true,
      0,
    })
  end
end
