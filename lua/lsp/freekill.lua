-- SPDX-License-Identifier: GPL-3.0-or-later

---@meta

-- Note: these files are not used by FreeKill.
-- Just for convenience when using sumneko.lua

---@alias null nil
---@alias bool boolean | nil

---@class fk
---FreeKill's lua API
fk = {}

---@class MarkEnum
---Special marks
MarkEnum = {}

---@class fk.SPlayerList
SPlayerList = {}

--- * get microsecond from Epoch
---@return integer microsecond
function fk:GetMicroSecond()end

--- construct a QList<ServerPlayer *>.
---@return fk.SPlayerList
function fk:SPlayerList()end

function fk.QmlBackend_pwd()end

---@return string[]
function fk.QmlBackend_ls(filename)end
function fk.QmlBackend_cd(dir)end

---@return boolean
function fk.QmlBackend_exists(file)end

---@return boolean
function fk.QmlBackend_isDir(file)end

function fk.qCritical(msg) end
function fk.qInfo(msg) end
function fk.qDebug(msg) end
function fk.qWarning(msg) end
