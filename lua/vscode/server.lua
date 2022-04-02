---@meta

---@class fk.Server
FServer = {}

---@type fk.Server
fk.ServerInstance = {}

---@class fk.Room
--- Room (C++)
FRoom = {}

---@param owner fk.ServerPlayer
---@param name string
---@param capacity integer
function FServer:createRoom(owner,name,capacity)end

---@param id integer
---@return fk.Room
function FServer:findRoom(id)end

---@return fk.Room
function FServer:lobby()end

---@param id integer
---@return fk.ServerPlayer
function FServer:findPlayer(id)end

---@return fk.SQLite3
function FServer:getDatabase()end

function FRoom:getServer()end
function FRoom:getId()end
function FRoom:isLobby()end
function FRoom:getName()end
function FRoom:setName(name)end
function FRoom:getCapacity()end
function FRoom:setCapacity(capacity)end
function FRoom:isFull()end
function FRoom:isAbandoned()end
function FRoom:addPlayer(player)end
function FRoom:removePlayer(player)end
function FRoom:getOwner()end
function FRoom:setOwner(owner)end
function FRoom:getPlayers()end
function FRoom:findPlayer(id)end
function FRoom:getTimeout()end
function FRoom:isStarted()end
function FRoom:doBroadcastNotify(targets,command,jsonData)end
function FRoom:gameOver()end
