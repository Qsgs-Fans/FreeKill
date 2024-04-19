-- SPDX-License-Identifier: GPL-3.0-or-later

---@meta

---@class fk.Player
FPlayer = {}

function FPlayer:getId()end
function FPlayer:getScreenName()end
function FPlayer:getAvatar()end

---@class fk.ServerPlayer : fk.Player
FServerPlayer = {}

function FServerPlayer:doRequest(command,jsonData,timeout)end
function FServerPlayer:waitForReply(timeout)end
function FServerPlayer:doNotify(command,jsonData)end
function FServerPlayer:setBusy(_) end
function FServerPlayer:isBusy(_) end
function FServerPlayer:setThinking(_) end

function FServerPlayer:getState() end

---@type any
fk.Self = nil
