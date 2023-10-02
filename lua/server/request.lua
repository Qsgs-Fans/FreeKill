-- SPDX-License-Identifier: GPL-3.0-or-later

local function tellRoomToObserver(self, player)
  local observee = self.players[1]
  player:doNotify("Setup", json.encode{
    observee.id,
    observee._splayer:getScreenName(),
    observee._splayer:getAvatar(),
  })
  player:doNotify("EnterRoom", json.encode{
    #self.players, self.timeout, self.settings
  })
  player:doNotify("StartGame", "")

  -- send player data
  for _, p in ipairs(self:getOtherPlayers(observee, false, true)) do
    player:doNotify("AddPlayer", json.encode{
      p.id,
      p._splayer:getScreenName(),
      p._splayer:getAvatar(),
    })
  end

  local player_circle = {}
  for i = 1, #self.players do
    table.insert(player_circle, self.players[i].id)
  end
  player:doNotify("ArrangeSeats", json.encode(player_circle))

  -- send printed_cards
  for i = -2, -math.huge, -1 do
    local c = Fk.printed_cards[i]
    if not c then break end
    player:doNotify("PrintCard", json.encode{ c.name, c.suit, c.number })
  end

  -- send card marks
  for id, marks in pairs(self.card_marks) do
    for k, v in pairs(marks) do
      player:doNotify("SetCardMark", json.encode{ id, k, v })
    end
  end

  for _, p in ipairs(self.players) do
    self:notifyProperty(player, p, "general")
    self:notifyProperty(player, p, "deputyGeneral")
    p:marshal(player, true)
  end

  player:doNotify("UpdateDrawPile", #self.draw_pile)
  player:doNotify("UpdateRoundNum", self:getTag("RoundCount") or 0)

  table.insert(self.observers, {observee.id, player, player:getId()})
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
    local pid = t[3]
    if pid == id then
      table.removeOne(self.observers, t)
      self:doBroadcastNotify("RemoveObserver", json.encode{ pid })
      break
    end
  end
end

local request_handlers = {}
request_handlers["reconnect"] = function(room, id, reqlist)
  local p = room:getPlayerById(id)
  if p then
    p:reconnect()
  end
end

request_handlers["observe"] = function(room, id, reqlist)
  addObserver(room, id)
end

request_handlers["leave"] = function(room, id, reqlist)
  removeObserver(room, id)
end

request_handlers["prelight"] = function(room, id, reqlist)
  local p = room:getPlayerById(id)
  if p then
    p:prelightSkill(reqlist[3], reqlist[4] == "true")
  end
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
  else
    p.serverplayer:setThinking(false)
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
    special_cards = to.special_cards,
  })
end

request_handlers["surrender"] = function(room, id, reqlist)
  local player = room:getPlayerById(id)
  if not player then return end
  local logic = room.logic
  local curEvent = logic:getCurrentEvent()
  if curEvent then
    curEvent:addExitFunc(
      function()
        player.surrendered = true
        room:broadcastProperty(player, "surrendered")
        room:gameOver(Fk.game_modes[room.settings.gameMode]:getWinner(player))
      end
    )
    room.hasSurrendered = true
    room:doBroadcastNotify("CancelRequest", "")
  end
end

request_handlers["newroom"] = function(s, id)
  s:registerRoom(id)
end

-- 处理异步请求的协程，本身也是个死循环就是了。
-- 为了适应调度器，目前又暂且将请求分为“耗时请求”和不耗时请求。
-- 耗时请求处理后会立刻挂起。不耗时的请求则会不断处理直到请求队列空后再挂起。
local function requestLoop(self)
  while true do
    local ret = false
    local request = self.thread:fetchRequest()
    if request ~= "" then
      ret = true
      local reqlist = request:split(",")
      local roomId = tonumber(table.remove(reqlist, 1))
      local room = self:getRoom(roomId)

      if room then
        RoomInstance = room
        local id = tonumber(reqlist[1])
        local command = reqlist[2]
        Pcall(request_handlers[command], room, id, reqlist)
        RoomInstance = nil
      end
    end
    if not ret then
      coroutine.yield()
    end
  end
end

return requestLoop
