---@meta

-- Note: these files are not used by FreeKill.
-- Just for convenience when using sumneko.lua

---@class freekill
---FreeKill's lua API
freekill = {}

---@class freekill.SPlayerList
SPlayerList = {}

--- * get microsecond from Epoch
---@return number microsecond
function freekill:GetMicroSecond()end

--- construct a QList<ServerPlayer *>.
---@return freekill.SPlayerList
function freekill:SPlayerList()end

function freekill.QmlBackend_pwd()end
function freekill.QmlBackend_ls(filename)end
function freekill.QmlBackend_cd(dir)end
function freekill.QmlBackend_exists(file)end
function freekill.QmlBackend_isDir(file)end
