---@meta

---@return number length
function SPlayerList:length()end

---@param e fk.ServerPlayer
function SPlayerList:append(e)end

---@param e fk.ServerPlayer
---@return boolean
function SPlayerList:contains(e)end

---@param index number
---@return fk.ServerPlayer | nil
function SPlayerList:at(index)end

function SPlayerList:first()end
function SPlayerList:last()end
function SPlayerList:isEmpty()end
function SPlayerList:removeAt(index)end
function SPlayerList:removeAll()end
function SPlayerList:indexOf(e)end
