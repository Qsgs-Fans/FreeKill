---@class ServerPlayer : Player
---@field serverplayer fk.ServerPlayer
---@field room Room
---@field next ServerPlayer
---@field request_data string
---@field client_reply string
---@field default_reply string
---@field reply_ready boolean
local ServerPlayer = Player:subclass("ServerPlayer")

function ServerPlayer:initialize(_self)
    Player.initialize(self)
    self.serverplayer = _self
    self.room = nil

    self.next = nil

    -- Below are for doBroadcastRequest
    self.request_data = ""
    self.client_reply = ""
    self.default_reply = ""
    self.reply_ready = false
end

---@return integer
function ServerPlayer:getId()
    return self.serverplayer:getId()
end

---@param command string
---@param jsonData string
function ServerPlayer:doNotify(command, jsonData)
    self.serverplayer:doNotify(command, jsonData)
end

--- Send a request to client, and allow client to reply within *timeout* seconds.
---
--- *timeout* must not be negative. If nil, room.timeout is used.
---@param command string
---@param jsonData string
---@param timeout integer
function ServerPlayer:doRequest(command, jsonData, timeout)
    timeout = timeout or self.room.timeout
    self.client_reply = ""
    self.reply_ready = false
    self.serverplayer:doRequest(command, jsonData, timeout)
end

--- Wait for at most *timeout* seconds for reply from client.
---
--- If *timeout* is negative or **nil**, the function will wait forever until get reply.
---@param timeout integer # seconds to wait
---@return string reply # JSON data
function ServerPlayer:waitForReply(timeout)
    local result = ""
    if timeout == nil then
        result = self.serverplayer:waitForReply()
    else
        result = self.serverplayer:waitForReply(timeout)
    end
    self.request_data = ""
    self.client_reply = result
    if result ~= "" then self.reply_ready = true end
    return result
end

return ServerPlayer
