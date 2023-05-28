-- SPDX-License-Identifier: GPL-3.0-or-later

local function tellRoomToObserver(self, player)
  local observee = self.players[1]
  player:doNotify("Setup", json.encode{
    observee.id,
    observee.serverplayer:getScreenName(),
    observee.serverplayer:getAvatar(),
  })
  player:doNotify("EnterRoom", json.encode{
    #self.players, self.timeout, self.settings
  })
  player:doNotify("StartGame", "")

  -- send player data
  for _, p in ipairs(self:getOtherPlayers(observee, true, true)) do
    player:doNotify("AddPlayer", json.encode{
      p.id,
      p.serverplayer:getScreenName(),
      p.serverplayer:getAvatar(),
    })
  end

  local player_circle = {}
  for i = 1, #self.players do
    table.insert(player_circle, self.players[i].id)
  end
  player:doNotify("ArrangeSeats", json.encode(player_circle))

  for _, p in ipairs(self.players) do
    self:notifyProperty(player, p, "general")
    self:notifyProperty(player, p, "deputyGeneral")
    p:marshal(player)
  end

  player:doNotify("UpdateDrawPile", #self.draw_pile)
  player:doNotify("UpdateRoundNum", self:getTag("RoundCount") or 0)

  table.insert(self.observers, {observee.id, player})
end

local function addObserver(self, id)
  local all_observers = self.room:getObservers()
  for _, p in fk.qlist(all_observers) do
    if p:getId() == id then
      tellRoomToObserver(self, p)
      self:doBroadcastNotify("AddObserver", json.encode{
        p:getId(),
        p:getScreenName(),
        p:getAvatar()
      })
      break
    end
  end
end

local function removeObserver(self, id)
  for _, t in ipairs(self.observers) do
    local __, p = table.unpack(t)
    if p:getId() == id then
      table.removeOne(self.observers, t)
      self:doBroadcastNotify("RemoveObserver", json.encode{
        p:getId(),
      })
      break
    end
  end
end

local request_handlers = {}
request_handlers["reconnect"] = function(room, id, reqlist)
  local p = room:getPlayerById(id)
  p:reconnect()
end

request_handlers["observe"] = function(room, id, reqlist)
  addObserver(room, id)
end

request_handlers["leave"] = function(room, id, reqlist)
  removeObserver(room, id)
end

request_handlers["prelight"] = function(room, id, reqlist)
  local p = room:getPlayerById(id)
  p:prelightSkill(reqlist[3], reqlist[4] == "true")
end

request_handlers["luckcard"] = function(room, id, reqlist)
  local p = room:getPlayerById(id)
  local cancel = reqlist[3] == "false"
  local luck_data = room:getTag("LuckCardData")
  if not (p and luck_data) then return end
  local pdata = luck_data[id]

  if not cancel then
    pdata.luckTime = pdata.luckTime - 1
    luck_data.discardInit(room, p)
    luck_data.drawInit(room, p, pdata.num)
  else
    pdata.luckTime = 0
  end

  if pdata.luckTime > 0 then
    p:doNotify("AskForLuckCard", pdata.luckTime)
  end

  room:setTag("LuckCardData", luck_data)
end

request_handlers["changeself"] = function(room, id, reqlist)
  local p = room:getPlayerById(id)
  local toId = tonumber(reqlist[3])
  local from = p
  local to = room:getPlayerById(toId)
  local from_sp = from._splayer

  -- 注意发来信息的玩家的主视角可能已经不是自己了
  -- 先换成正确的玩家
  from = table.find(room.players, function(p)
    return table.contains(p._observers, from_sp)
  end)

  -- 切换视角
  table.removeOne(from._observers, from_sp)
  table.insert(to._observers, from_sp)
  from_sp:doNotify("ChangeSelf", json.encode {
    id = toId,
    handcards = to:getCardIds(Player.Hand),
  })
end

local function requestLoop(self)
  local rest_time = 0
  while true do
    local ret = false
    local request = self.room:fetchRequest()
    if request ~= "" then
      ret = true
      local reqlist = request:split(",")
      local id = tonumber(reqlist[1])
      local command = reqlist[2]
      request_handlers[command](self, id, reqlist)
    elseif rest_time > 10 then
      -- let current thread sleep 10ms
      -- otherwise CPU usage will be 100% (infinite yield <-> resume loop)
      fk.QThread_msleep(10)
    end
    rest_time = coroutine.yield(ret)
  end
end

return requestLoop
