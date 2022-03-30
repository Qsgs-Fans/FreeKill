---@meta

---@return number length
function SPlayerList:length()end

---@param e freekill.ServerPlayer
function SPlayerList:append(e)end

---@param e freekill.ServerPlayer
---@return boolean
function SPlayerList:contains(e)end

---@param index number
---@return freekill.ServerPlayer | nil
function SPlayerList:at(index)end

function SPlayerList:first()end
function SPlayerList:last()end
function SPlayerList:isEmpty()end
function SPlayerList:removeAt(index)end
function SPlayerList:removeAll()end
function SPlayerList:indexOf(e)end
