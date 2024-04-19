-- SPDX-License-Identifier: GPL-3.0-or-later

---@diagnostic disable

---@class fk.Room
local Room = {}

function Room:getId() return 1 end

---@return fk.SPlayerList
function Room:getPlayers() end

---@return fk.SPlayerList
function Room:getObservers() end
