-- SPDX-License-Identifier: GPL-3.0-or-later

---@meta

---@class fk.Player
FPlayer = {}

---@return integer id
function FPlayer:getId()end

---@return string name
function FPlayer:getScreenName()end

---@return string avatar
function FPlayer:getAvatar()end

---@class fk.ServerPlayer : fk.Player
FServerPlayer = {}

--- Send a request to client, and allow client to reply within *timeout* seconds.
---
--- *timeout* must not be negative or **nil**.
---@param command string
---@param jsonData string
---@param timeout integer
function FServerPlayer:doRequest(command,jsonData,timeout)end

--- Wait for at most *timeout* seconds for reply from client.
---
--- If *timeout* is negative or **nil**, the function will wait forever until get reply.
---@param timeout integer @ seconds to wait
---@return string @ JSON data
---@overload fun()
function FServerPlayer:waitForReply(timeout)end

--- Notice the client.
---@param command string
---@param jsonData string
function FServerPlayer:doNotify(command,jsonData)end

function FServerPlayer:setBusy(_) end
function FServerPlayer:isBusy(_) end
function FServerPlayer:setThinking(_) end

function FServerPlayer:getState() end
