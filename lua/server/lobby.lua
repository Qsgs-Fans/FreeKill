---@class Lobby : Object
---@field lobby fk.Room
Lobby = class("Lobby")

fk.lobby_callback = {}
local db = fk.ServerInstance:getDatabase()

function Lobby:initialize(_lobby)
  self.lobby = _lobby
  self.lobby.callback = function(_self, command, jsonData)
    local cb = fk.lobby_callback[command]
    if (type(cb) == "function") then
      cb(jsonData)
    else
      print("Lobby error: Unknown command " .. command);
    end
  end
end

fk.lobby_callback["UpdateAvatar"] = function(jsonData)
  -- jsonData: [ int uid, string newavatar ]
  local data = json.decode(jsonData)
  local id, avatar = data[1], data[2]
  local sql = "UPDATE userinfo SET avatar='%s' WHERE id=%d;"
  Sql.exec(db, string.format(sql, avatar, id))
  local player = fk.ServerInstance:findPlayer(id)
  player:setAvatar(avatar)
  player:doNotify("UpdateAvatar", avatar)
end

fk.lobby_callback["UpdatePassword"] = function(jsonData)
  -- jsonData: [ int uid, string oldpassword, int newpassword ]
  local data = json.decode(jsonData)
  local id, old, new = data[1], data[2], data[3]
  local sql_find = "SELECT password FROM userinfo WHERE id=%d;"
  local sql_update = "UPDATE userinfo SET password='%s' WHERE id=%d;"

  local passed = false
  local result = Sql.exec_select(db, string.format(sql_find, id))
  passed = (result["password"][1] == sha256(old))
  if passed then
    Sql.exec(db, string.format(sql_update, sha256(new), id))
  end

  local player = fk.ServerInstance:findPlayer(tonumber(id))
  player:doNotify("UpdatePassword", passed and "1" or "0")
end

fk.lobby_callback["CreateRoom"] = function(jsonData)
  -- jsonData: [ int uid, string name, int capacity ]
  local data = json.decode(jsonData)
  local owner = fk.ServerInstance:findPlayer(tonumber(data[1]))
  local roomName = data[2]
  local capacity = data[3]
  fk.ServerInstance:createRoom(owner, roomName, capacity)
end

fk.lobby_callback["EnterRoom"] = function(jsonData)
  -- jsonData: [ int uid, int roomId ]
  local data = json.decode(jsonData)
  local player = fk.ServerInstance:findPlayer(tonumber(data[1]))
  local room = fk.ServerInstance:findRoom(tonumber(data[2]))
  room:addPlayer(player)
end

function CreateRoom(_room)
  LobbyInstance = Lobby:new(_room)
end
