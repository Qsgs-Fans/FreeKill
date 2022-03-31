---@meta

-- Note: these files are not used by FreeKill.
-- Just for convenience when using sumneko.lua

---@class fk
---FreeKill's lua API
fk = {}

---@class fk.SPlayerList
SPlayerList = {}

--- * get microsecond from Epoch
---@return number microsecond
function fk:GetMicroSecond()end

--- construct a QList<ServerPlayer *>.
---@return fk.SPlayerList
function fk:SPlayerList()end

function fk.QmlBackend_pwd()end
function fk.QmlBackend_ls(filename)end
function fk.QmlBackend_cd(dir)end
function fk.QmlBackend_exists(file)end
function fk.QmlBackend_isDir(file)end
