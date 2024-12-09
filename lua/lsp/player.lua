-- SPDX-License-Identifier: GPL-3.0-or-later

---@meta

---@class fk.Player
---@field private id integer
---@field private screenName string
---@field private avatar string
---@field private state integer
---@field private died boolean
---@field public _fake_router fk.Client
local FPlayer = {}

---@return integer
function FPlayer:getId()
  return self.id
end

---@param id integer
function FPlayer:setId(id)
  self.id = id
end

---@return string
function FPlayer:getScreenName()
  return self.screenName
end

---@param name string
function FPlayer:setScreenName(name)
  self.screenName = name
end

---@return string
function FPlayer:getAvatar()
  return self.avatar
end

---@param avatar string
function FPlayer:setAvatar(avatar)
  self.avatar = avatar
end

---@return integer
function FPlayer:getTotalGameTime()
  return 0
end

---@param toAdd integer
function FPlayer:addTotalGameTime(toAdd) end

---@return integer
function FPlayer:getState()
  return self.state
end

---@param state integer
function FPlayer:setState(state)
  self.state = state
end

---@return integer[]
function FPlayer:getGameData()
end

---@param total integer
---@param win integer
---@param run integer
function FPlayer:setGameData(total, win, run) end

---@return boolean
function FPlayer:isDied()
  return self.died
end

---@param died boolean
function FPlayer:setDied(died)
  self.died = died
end

return FPlayer
