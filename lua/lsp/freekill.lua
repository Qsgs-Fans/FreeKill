-- SPDX-License-Identifier: GPL-3.0-or-later

---@meta

-- Note: these files are not used by FreeKill.
-- Just for convenience when using sumneko.lua

---@alias null nil

---@class fk
---FreeKill's lua API
fk = {}

---@class MarkEnum
---Special marks
MarkEnum = {}

---@class fk.QmlBackend
local FQmlBackend = {}

---@param path string
function FQmlBackend.cd(path)
end

---@param dir string
---@return string[]
function FQmlBackend.ls(dir)
end

---@return string
function FQmlBackend.pwd()
end

---@param file string
---@return boolean
function FQmlBackend.exists(file)
end

---@param file string
---@return boolean
function FQmlBackend.isDir(file)
end

-- External instance of QmlBackend
fk.Backend = FQmlBackend

-- Static method references
fk.QmlBackend_cd = FQmlBackend.cd
fk.QmlBackend_ls = FQmlBackend.ls
fk.QmlBackend_pwd = FQmlBackend.pwd
fk.QmlBackend_exists = FQmlBackend.exists
fk.QmlBackend_isDir = FQmlBackend.isDir

-- Enum definition
fk.Player_Invalid = 0
fk.Player_Online = 1
fk.Player_Trust = 2
fk.Player_Run = 3
fk.Player_Leave = 4
fk.Player_Robot = 5
fk.Player_Offline = 6

--- * get microsecond from Epoch
---@return integer microsecond
function fk:GetMicroSecond()end

-- Logging functions
function fk.qDebug(msg, ...)
end

function fk.qInfo(msg, ...)
end

function fk.qWarning(msg, ...)
end

function fk.qCritical(msg, ...)
end

---@class fk.QJsonDocument
local FQJsonDocument = {}

---@param json string
---@return fk.QJsonDocument
function fk.QJsonDocument_fromJson(json)
end

---@return fk.QJsonDocument
function fk.QJsonDocument_fromVariant(variant)
end

---@return string
function FQJsonDocument:toJson(format)
end

---@return any
function FQJsonDocument:toVariant()
end

fk.FK_VER = '0.0.0'
