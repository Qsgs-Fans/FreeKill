-- SPDX-License-Identifier: GPL-3.0-or-later

-- AI base class.
-- Do nothing.

---@class AI: Object
---@field public room Room
---@field public player ServerPlayer
---@field public command string
---@field public jsonData string
---@field public cb_table table<string, fun(self: AI, jsonData: string)>
local AI = class("AI")

function AI:initialize(player)
  self.room = RoomInstance
  self.player = player
  local cb_t = {}
  -- default strategy: print command and data, then return ""
  setmetatable(cb_t, {
    __index = function()
      return function()
        print(self.command, self.jsonData)
        return ""
      end
    end,
  })
  self.cb_table = cb_t
end

function AI:readRequestData()
  self.command = self.player.ai_data.command
  self.jsonData = self.player.ai_data.jsonData
end

function AI:makeReply()
  Self = self.player
  local start = os.getms()
  local ret = self.cb_table[self.command] and self.cb_table[self.command](self, self.jsonData) or "__cancel"
  local to_delay = 500 - (os.getms() - start) / 1000
  -- print(to_delay)
  self.room:delay(to_delay)
  return ret
end

return AI
