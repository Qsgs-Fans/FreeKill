---@meta

---@class fk.Player
FPlayer = {}

---@return integer id
function FPlayer:getId()end

---@param id integer
function FPlayer:setId(id)end

---@return string name
function FPlayer:getScreenName()end

---@param name string
function FPlayer:setScreenName(name)end

---@return string avatar
function FPlayer:getAvatar()end

---@param avatar string
function FPlayer:setAvatar(avatar)end

---@return string state
function FPlayer:getStateString()end

---@param state string
function FPlayer:setStateString(state)end

---@class fk.ServerPlayer : fk.Player
FServerPlayer = {}

---@return fk.Server
function FServerPlayer:getServer()end

---@return fk.Room
function FServerPlayer:getRoom()end

---@param room fk.Room
function FServerPlayer:setRoom(room)end

---@param msg string
function FServerPlayer:speak(msg)end

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
---@param timeout integer # seconds to wait
---@return string reply # JSON data
---@overload fun()
function FServerPlayer:waitForReply(timeout)end

--- Notice the client.
---@param command string
---@param jsonData string
function FServerPlayer:doNotify(command,jsonData)end
