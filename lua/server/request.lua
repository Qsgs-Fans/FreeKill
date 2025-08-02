-- SPDX-License-Identifier: GPL-3.0-or-later

-- 本文件是用来处理各种异步请求的
-- 与游戏中常见的请求-答复没有什么联系

local function tellRoomToObserver(self, player)
  local observee = self.players[1]
  local start_time = os.getms()
  local summary = self:toJsonObject(observee)
  player:doNotify("Observe", cbor.encode(summary))

  fk.qInfo(string.format("[Observe] %d, %s, in %.3fms",
    self.id, player:getScreenName(), (os.getms() - start_time) / 1000))

  table.insert(self.observers, {observee.id, player, player:getId()})
end

local function addObserver(self, id)
  local all_observers = self.room:getObservers()
  for _, p in fk.qlist(all_observers) do
    if p:getId() == id then
      tellRoomToObserver(self, p)
      self:doBroadcastNotify("AddObserver", {
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
      self:doBroadcastNotify("RemoveObserver", { pid })
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

request_handlers["surrender"] = function(room, id, reqlist)
  local player = room:getPlayerById(id)
  if not player then return end

  player.surrendered = true
  if Fk.game_modes[room.settings.gameMode]:getWinner(player) == "" then
    player.surrendered = false
    return
  end

  room.hasSurrendered = true
  room:doBroadcastNotify("CancelRequest", "")
  ResumeRoom(room.id)
end

request_handlers["updatemini"] = function(room, pid, reqlist)
  local player = room:getPlayerById(pid)
  local data = player.mini_game_data
  if not data then return end
  local game = Fk.mini_games[data.type]
  if not (game and game.update_func) then return end
  local dat = table.simpleClone(reqlist)
  table.remove(dat, 1)
  table.remove(dat, 1)
  game.update_func(player, dat)
end

request_handlers["newroom"] = function(s, id)
  s:registerRoom(id)
  ResumeRoom(id)
end

request_handlers["reloadpackage"] = function(_, _, reqlist)
  if not IsConsoleStart() then return end
  local path = reqlist[3]
  Fk:reloadPackage(path)
end

return function(self, request)
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
