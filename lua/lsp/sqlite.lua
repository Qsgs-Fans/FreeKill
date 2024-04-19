-- SPDX-License-Identifier: GPL-3.0-or-later
-- 暂且用来当client.lua用了，别在意

---@class fk.Client
---@field callback fun(s: fk.Client, c: string, j: string, r: boolean)
local C = {}

function C:replyToServer(c, j) end
function C:notifyServer(c, j) end
function C:addPlayer(id, name, avatar) end
function C:removePlayer(id) end
function C:changeSelf(id) end
function C:saveRecord(j, fname) end

fk.ClientInstance = C

---@class fk.QmlBackend
local B = {}

function B:emitNotifyUI(c, j) end

fk.Backend = B
