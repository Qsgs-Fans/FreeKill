-- SPDX-License-Identifier: GPL-3.0-or-later

---@class SmartAI: AI
local SmartAI = AI:subclass("RandomAI")

function SmartAI:initialize(player)
  AI.initialize(self, player)
end

return SmartAI
