-- SPDX-License-Identifier: GPL-3.0-or-later

-- Trust AI

---@class TrustAI: AI
local TrustAI = AI:subclass("TrustAI")

local trust_cb = {}

function TrustAI:initialize(player)
  AI.initialize(self, player)
  self.cb_table = trust_cb
end

return TrustAI
