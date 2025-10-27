-- 应该是RoomBase<T> 但是只能写个RoomBase<Base.Player>了

---@class Base.RoomBase : Object
---@field public players Base.Player[] @ 房内参战角色们
---@field public observers Base.Player[] @ 看戏的
---@field public current Base.Player @ 当前行动者
---@field public capacity integer @ 房间的最大参战人数
---@field public timeout integer @ 出牌时长上限
---@field public settings table @ 房间的额外设置，差不多是json对象
---@field public request_handlers table<string, RequestHandler> @ 请求处理程序
---@field public current_request_handler RequestHandler @ 当前正处理的请求数据
---@field public banners table<string, any> @ 全局mark
local RoomBase = class("Base.RoomBase")

function RoomBase:initialize()
  self.players = {}
  self.observers = {}
  self.current = nil

  self.banners = {}

  self.request_handlers = {}
end

---@param command string
---@param handler RequestHandler
function RoomBase:addRequestHandler(command, handler)
  self.request_handlers[command] = handler
end

---@param command string
function RoomBase:setupRequestHandler(player, command, data)
  local handler = self.request_handlers[command]
  local h = handler:new(player, data)
  h.change = {}
  h:setup()
  h.scene:notifyUI()
end

-- 仅供注释，其余空函数一样

--- 根据角色id，获得那名角色本人
---@param id integer @ 角色的id
---@return Base.Player
function RoomBase:getPlayerById(id)
  ---@diagnostic disable-next-line
  return table.find(self.players, function(p) return p.id == id end)
end

-- 根据角色座位号，获得那名角色本人
---@param seat integer
---@return Base.Player
function RoomBase:getPlayerBySeat(seat)
  ---@diagnostic disable-next-line
  return table.find(self.players, function(p) return p.seat == seat end)
end

--- 设置房间的当前行动者
---@param player Player
function RoomBase:setCurrent(player)
  self.current = player
end

---@return Base.Player? @ 当前回合角色
function RoomBase:getCurrent()
  return self.current
end

--- 设置房间banner于左上角，用于模式介绍，仁区等
function RoomBase:setBanner(name, value)
  if value == 0 then value = nil end
  self.banners[name] = value
end

--- 获得房间的banner，如果不存在则返回nil
function RoomBase:getBanner(name)
  local v = self.banners[name]
  if type(v) == "table" and not Util.isCborObject(v) then
    return table.simpleClone(v)
  end
  return v
end

-- 读取key对应的配置项
function RoomBase:getSettings(key)
  local t = self.settings
  if t._mode and t._mode[key] ~= nil then return t._mode[key] end
  if t._game and t._game[key] ~= nil then return t._game[key] end
  return t[key]
end

-- 底层逻辑这一块之序列化和反序列化

function RoomBase:serialize()
  local players = {}
  for _, p in ipairs(self.players) do
    players[p.id] = p:serialize()
  end

  return {
    circle = table.map(self.players, Util.IdMapper),
    current = self.current and self.current.id or nil,
    capacity = self.capacity,
    timeout = self.timeout,
    settings = self.settings,
    banners = cbor.encode(self.banners),

    players = players,
  }
end

function RoomBase:deserialize(o)
  self.current = self:getPlayerById(o.current)
  self.capacity = o.capacity or #self.players
  self.timeout = o.timeout
  self.settings = o.settings

  -- 需要上层（目前是Client）自己根据circle添加玩家
  for k, v in pairs(o.players) do
    self:getPlayerById(k):deserialize(v)
  end

  self.banners = cbor.decode(o.banners)
end

return RoomBase
