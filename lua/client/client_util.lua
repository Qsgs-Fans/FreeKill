-- SPDX-License-Identifier: GPL-3.0-or-later

-- All functions in this file are used by Qml

function Translate(src)
  return Fk:translate(src)
end

function GetGameModes()
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    local pk = Fk.packages[name]
    for _, v in ipairs(pk.game_modes) do
      table.insert(ret, {
        name = Fk:translate(v.name),
        orig_name = v.name,
        minPlayer = v.minPlayer,
        maxPlayer = v.maxPlayer,
      })
    end
  end
  -- table.sort(ret, function(a, b) return a.name > b.name end)
  return ret
end

-- 重新创建Lua client，但是继承ClientBase之类的数据，将和游戏状态有关的数据抹杀
-- 继承的数据只要足以支持等待界面的房间就行
function ResetClientLua()
  local self = ClientInstance
  local client_klass = self.class --[[@as Client]]
  local cpp_client = self.client

  -- 最优先处理自己是旁观者时的返回房间
  if self.observing and self.observer_setup_data then
    local t = self.observer_setup_data
    local selfp = cpp_client:addPlayer(t[1], t[2], t[3])
    selfp:addTotalGameTime(Self.player:getTotalGameTime())
    cpp_client:changeSelf(t[1])
    Self = self:createPlayer(selfp)
    self.observer_setup_data = nil
  end
  local cpp_players = table.map(self.players, function(p)
    return { p.player, p.ready, p.owner }
  end)
  -- FIXME 擦屁股之Qt版server没给机器人发removePlayer
  cpp_players = table.filter(cpp_players, function(arr)
    return arr[1]:getId() > 0
  end)

  -- 保留旁观者列表（结构为 {0, player, id}），供返回房间旁观区域使用
  local observers = table.map(self.observers or {}, function(t)
    return { t[3], t[2]:getScreenName(), t[2]:getAvatar(), false, t[2]:getTotalGameTime() }
  end)

  local _data = self.enter_room_data

  self = client_klass:new(cpp_client) -- clear old client data
  self.players = table.map(cpp_players, function(p)
    local cp = self:createPlayer(p[1])
    cp.ready = p[2]
    cp.owner = p[3]
    return cp
  end)
  -- 注意如果在开战前的ob的话会取不到Self
  Self = self:getPlayerById(Self.id) or Self

  -- 恢复旁观者列表
  self.observers = table.map(observers, function(o)
    local id, name, avatar, gameTime = o[1], o[2], o[3], o[5]
    local player = {
      getId = function() return id end,
      getScreenName = function() return name end,
      getAvatar = function() return avatar end,
      getState = function() return fk.Player_Online end,
      getTotalGameTime = function() return gameTime end,
    }
    return { 0, player, id }
  end)

  self.enter_room_data = _data;
  local data = cbor.decode(_data)
  self.capacity = data[1]
  self.timeout = data[2]
  self.settings = data[3]

  -- 刷新 _players / _observers，供等待界面初始化使用
  local settings = self.settings
  settings._players = table.map(cpp_players, function(p)
    local cp = p[1]
    return { cp:getId(), cp:getScreenName(), cp:getAvatar(),
             p[2] == true, cp:getTotalGameTime(), p[3] == true }
  end)

  -- FIXME 怎么混入三国杀要素了，非常坏
  self.disabled_packs = ClientInstance.disabled_packs
  self.disabled_generals = ClientInstance.disabled_generals
  ClientInstance = self
end

function GetCompNum()
  local c = ClientInstance
  local mode = Fk.game_modes[c:getSettings('gameMode')] or Fk.game_modes["aaa_role_mode"]
  local min, max = mode.minComp, mode.maxComp
  local capacity = c.capacity
  if min < 0 then min = capacity + min end
  if max < 0 then max = capacity + max end
  min = math.min(min, max) -- 最小值大于最大值时，取较小的
  local compNum = #table.filter(c.players, function(pl) return pl.id < -1 end)
  return { minComp = min, maxComp = max, curComp = compNum }
end

function GetPlayerGameData(pid)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  if not p then return { 0, 0, 0, 0 } end
  local raw = p.player:getGameData()
  local ret = {}
  for _, i in fk.qlist(raw) do
    table.insert(ret, i)
  end
  table.insert(ret, p.player:getTotalGameTime())
  return ret
end

function SetPlayerGameData(pid, data)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  local total, win, run = table.unpack(data)
  p.player:setGameData(total, win, run)
  table.insert(data, 1, pid)
  ClientInstance:notifyUI("UpdateGameData", data)
end

function SetObserving(o)
  ClientInstance.observing = o
end

function SetReplaying(o)
  ClientInstance.replaying = o
end

function SetReplayingShowCards(o)
  ClientInstance.replaying_show = o
  if o then
    for _, p in ipairs(ClientInstance.players) do
      ClientInstance:notifyUI("PropertyUpdate", { p.id, "role_shown", true })
    end
  end
end

function CheckSurrenderAvailable()
  local curMode = ClientInstance:getSettings('gameMode')
  local mode = Fk.game_modes[curMode] or Fk.game_modes["aaa_role_mode"]
  local playedTime = os.time() - ClientInstance.gameStartTime
  return mode:surrenderFunc(playedTime, Self)
end

function SaveRecord()
  local c = ClientInstance
  c.client:saveRecord(cbor.encode(c.record), c.record[2])
end

function GetQmlMark(mtype, name, p)
  local spec = Fk.qml_marks[mtype]
  if not spec then return {} end
  local value
  p = ClientInstance:getPlayerById(p)
  if p then
    local pile = p:getPile(name)
    if #pile > 0 then
      value = pile
    else
      value = p.mark[name]
    end
  else
    value = ClientInstance:getBanner(name)
  end
  if (not p) and (not value) or (value == 0) then return {} end
  local qmlData = spec.qml
  if type(qmlData) == "function" then
    qmlData = qmlData(name, value, p)
  elseif type(qmlData) == "table" then
    -- 避免所有qml全都要写function传入必须的值
    -- 如果不是函数的话，帮忙传入一下标记名、值和玩家id（如果有）
    local prop = qmlData.prop or {}
    prop.name = name
    prop.value = value
    prop.playerid = p and p.id
    qmlData.prop = prop
  end
  return {
    qml = qmlData,
    text = spec.how_to_show(name, value, p)
  }
end

local requestUIUpdating = false
function UpdateRequestUI(elemType, id, action, data)
  if requestUIUpdating then return end
  requestUIUpdating = true
  local h = ClientInstance.current_request_handler
  if not h then
    requestUIUpdating = false
    return
  end
  h.change = {}
  local finish = h:update(elemType, id, action, data)
  if not finish then
    h.scene:notifyUI()
  else
    h:_finish()
  end
  requestUIUpdating = false
end

function FinishRequestUI()
  local h = ClientInstance.current_request_handler
  if h then
    h:_finish()
    ClientInstance.current_request_handler = nil
  end
end

function GetPlayersAndObservers()
  local self = ClientInstance
  local ret = {}
  for _, p in ipairs(self.players) do
    local state = p.player:getState()
    if state == fk.Player_Run and p.dead then
      state = fk.Player_Offline
    end
    table.insert(ret, {
      id = table.contains(self.players, p) and p.id or p.player:getId(),
      general = p.general,
      deputy = p.deputyGeneral,
      name = p.player:getScreenName(),
      observing = table.contains(self.observers, p),
      state = state,
      avatar = p.player:getAvatar(),
      seat = p.seat,
    })
  end
  for _, p in ipairs(self.observers) do
    table.insert(ret, {
      id = p[2]:getId(),
      general = "",
      deputy = "",
      name = p[2]:getScreenName(),
      observing = true,
      state = fk.Player_Online,
      avatar = p[2]:getAvatar(),
      seat = -1,
    })
  end
  return ret
end

function ToUIString(v)
  local ok, obj = pcall(cbor.decode, v)
  if not ok then return "未知类型" end
  local mt = getmetatable(obj)
  if not mt then return "未知类型" end

  local f = mt.__touistring
  if f then
    local ret = f(obj)
    if type(ret) == "string" then
      return ret
    end
  end

  -- 这里故意返回中文
  return "未知类型"
end

local defaultQml = {
  -- 比照Qt.createComponent参数名而设
  uri = "QtQuick",
  name = "Rectangle",

  -- 或者可以写QML文件路径
  url = nil,

  -- 比照Component.createObject
  prop = {
    width = 80,
    height = 100,
    color = "green",
  },
}

function ToQml(v)
  local ok, obj = pcall(cbor.decode, v)
  if not ok then return defaultQml end
  local mt = getmetatable(obj)
  if not mt then return defaultQml end

  local f = mt.__toqml
  if f then
    local ret = f(obj)
    if type(ret) == "table" then
      return ret
    end
  end

  return defaultQml
end

local W = require "ui_emu.preferences"

function GetUIDataOfSettings(mode, settings, isBoardGame)
  local ui_settings
  if isBoardGame then
    ui_settings = Fk:getBoardGame(mode).ui_settings
  else
    ui_settings = Fk.game_modes[mode].ui_settings
  end

  if not ui_settings then return {} end
  return W.toQmlData(ui_settings, settings)
end

