-- Run tests with `ctest`
-- 本测试加载并运行和游戏逻辑有关的测试。
-- 测试途中应保证：
-- * 不能让房间切出，房间只能以gameOver形式结束运行。
-- * 也就是说，要屏蔽掉__handleRequest型的yield。

---@diagnostic disable: lowercase-global
--@diagnostic disable: undefined-global

__package.path = __package.path .. ";./test/lua/lib/?.lua"

fk.os = __os
fk.io = __io
lu = require('luaunit')
local consoleUI = require 'ui'

if UsingNewCore then FileIO.cd("packages/freekill-core") end
Room = require 'lua.server.room'
fk.Player = require 'lua.lsp.player'
local tmp = require 'lua.lsp.server'
fk.Room, fk.ServerPlayer = tmp[1], tmp[2]
fk.Client = require 'lua.lsp.client'
dofile 'lua/client/client.lua'

local createFakeQList = function(arr)
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
CreateFakePlayer = function(id, name, avatar)
  local ret = setmetatable({}, { __index = fk.ServerPlayer })
  ret:setId(id)
  ret:setScreenName(name or ("test_player_" .. id))
  ret:setAvatar(avatar or "guojia")
  ret:setState(id > 0 and fk.Player_Online or fk.Player_Robot)
  ret:setDied(false)
  ret:setThinking(false)
  return ret
end

local createFakeClient = function()
  local p = CreateFakePlayer(1)
  return setmetatable({
    _self = p,
    players = { [1] = p },
    _reply = "__cancel",
    _ui = consoleUI,
  }, { __index = fk.Client })
end

---@param idlist integer[]
---@return fk.Room
local createFakeRoom = function(idlist)
  local players = {}
  for _, id in ipairs(idlist) do
    table.insert(players, CreateFakePlayer(id))
  end
  local ret = setmetatable({
    id = 1,
    players = createFakeQList(players),
    owner = players[1],
    observers = createFakeQList{},
    timeout = 15,
    _settings = json.encode {
      enableFreeAssign = false,
      enableDeputy = false,
      gameMode = "aaa_role_mode",
      disabledPack = {},
      generalNum = 3,
      luckTime = 0,
      password = "",
      disabledGenerals = {},
    },
  }, { __index = fk.Room })

  return ret
end

local createFakeCppBackend = function()
  local cClient = createFakeClient()
  local idlist = {1, -2, -3, -4, -5, -6, -7, -8}
  local cRoom = createFakeRoom(idlist)
  local sp = cRoom:getOwner()
  sp._fake_router = cClient

  -- 以下代码全部忠于cpp原作
  CreateLuaClient(cClient)
  Self = ClientPlayer:new(cClient:getSelf())

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

local cRoom = createFakeCppBackend()
local room = Room:new(cRoom)
ClientSelf = Self
while not room.game_finished do
  RoomInstance = room
  local over, msg, ret, err = room:resume("request_timer")
  RoomInstance = nil
  if over then break end
end
Self = nil

dofile 'test/lua/server/gameevent.lua'

