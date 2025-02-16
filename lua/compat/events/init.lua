-- --- 将新数据改为牢数据
-- ---@return table
-- function TriggerData:toLegacy()
--   return table.simpleClone(rawget(self, "_data"))
-- end

-- --- 将牢数据改为新数据
-- ---@param data table
-- function TriggerData:loadLegacy(data)
--   for k, v in pairs(data) do
--     self[k] = v
--   end
-- end

require "compat.events.movecard"
require "compat.events.usecard"
require "compat.events.skill"
require "compat.events.pindian"
