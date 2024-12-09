-- SPDX-License-Identifier: GPL-3.0-or-later
-- 暂且用来当client.lua用了，别在意

---@meta

---@class fk.Client
---@field private _self fk.Player
---@field private players table<integer, fk.Player>
---@field public _reply_list any
---@field public _ui any
local FClient = {}

---@param pubkey string
function FClient:sendSetupPacket(pubkey) end

---@param server_time integer
function FClient:setupServerLag(server_time) end

---@param command string
---@param json_data string
function FClient:replyToServer(command, json_data) end

---@param command string
---@param json_data string
function FClient:notifyServer(command, json_data)
end

---@param id integer
---@param name string
---@param avatar string
---@return fk.Player
function FClient:addPlayer(id, name, avatar)
  self.players[id] = CreateFakePlayer(id, name, avatar)
  return self.players[id]
end

---@param id integer
function FClient:removePlayer(id)
  self.players[id] = nil
end

---@return fk.Player
function FClient:getSelf()
  return self._self
end

---@param id integer
function FClient:changeSelf(id)
  self._self = self.players[id] or self._self
end

---@param json string
---@param fname string
function FClient:saveRecord(json, fname) end

---@param mode string
---@param general string
---@param deputy string
---@param role string
---@param result integer
---@param replay string
---@param room_data string
---@param record string
function FClient:saveGameData(mode, general, deputy, role, result, replay, room_data, record) end

---@param command string
---@param jsonData any
function FClient:notifyUI(command, jsonData)
  self._ui.cb(command, jsonData)
end

function FClient:installMyAESKey() end

return FClient
