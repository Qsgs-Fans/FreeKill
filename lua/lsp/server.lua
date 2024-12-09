-- SPDX-License-Identifier: GPL-3.0-or-later

---@meta

---@class fk.Room
---@field private id integer
---@field private players fk.SPlayerList
---@field private owner fk.ServerPlayer
---@field private observers fk.SPlayerList
---@field private timeout integer
---@field private _settings string
local FRoom = {}

---@return integer
function FRoom:getId()
  return self.id
end

---@return fk.SPlayerList
function FRoom:getPlayers()
  return self.players
end

---@return fk.ServerPlayer
function FRoom:getOwner()
  return self.owner
end

---@return fk.SPlayerList
function FRoom:getObservers()
  return self.observers
end

---@param player fk.ServerPlayer
---@return boolean
function FRoom:hasObserver(player)
end

---@return integer
function FRoom:getTimeout()
  return self.timeout
end

---@param ms integer
function FRoom:delay(ms) end

---@param id integer
---@param mode string
---@param role string
---@param result integer
function FRoom:updatePlayerWinRate(id, mode, role, result) end

---@param general string
---@param mode string
---@param role string
---@param result integer
function FRoom:updateGeneralWinRate(general, mode, role, result) end

function FRoom:gameOver()
  for _, p in ipairs(self.players) do
    p:setDied(false)
    p:setThinking(false)
  end
end

---@param ms integer
function FRoom:setRequestTimer(ms) end

function FRoom:destroyRequestTimer() end

function FRoom:increaseRefCount() end

function FRoom:decreaseRefCount() end

---@return string
function FRoom:settings()
  return self._settings
end

---@class fk.RoomThread
local FRoomThread = {}

---@param id integer
---@return fk.Room
function FRoomThread:getRoom(id)
end

---@return boolean
function FRoomThread:isConsoleStart()
end

---@return boolean
function FRoomThread:isOutdated()
end

local FPlayer = require 'lua.lsp.player'

---@class fk.ServerPlayer : fk.Player
---@field private _thinking boolean
local FServerPlayer = setmetatable({}, { __index = FPlayer })

---@param command string
---@param json_data string
---@param timeout integer
---@param timestamp integer
function FServerPlayer:doRequest(command, json_data, timeout, timestamp)
  if self._fake_router then
    local room = RoomInstance
    RoomInstance = nil
    local s = Self
    Self = ClientSelf
    ClientCallback(self._fake_router, command, json_data, true)
    Self = s
    RoomInstance = room
  end
end

---@param timeout integer
---@return string
function FServerPlayer:waitForReply(timeout)
  if self._fake_router then
    local list = self._fake_router._reply_list
    local ret = table.remove(list, 1)
    if ret then return ret end
  end
  return "__cancel"
end

---@param command string
---@param json_data string
function FServerPlayer:doNotify(command, json_data)
  if self._fake_router then
    local room = RoomInstance
    RoomInstance = nil
    local s = Self
    Self = ClientSelf
    ClientCallback(self._fake_router, command, json_data, false)
    Self = s
    RoomInstance = room
  end
end

---@return boolean
function FServerPlayer:thinking()
  return self._thinking
end

---@param t boolean
function FServerPlayer:setThinking(t)
  self._thinking = t
end

function FServerPlayer:emitKick() end

return { FRoom, FServerPlayer }
