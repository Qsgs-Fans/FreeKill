-- AI base class.
-- Do nothing.

---@class AI: Object
---@field room Room
---@field player ServerPlayer
---@field command string
---@field jsonData string
---@field cb_table table<string, fun(jsonData: string)>
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
  local start = os.getms()
  local ret = self.cb_table[self.command] and self.cb_table[self.command](self, self.jsonData) or ""
  self.room:delay(700 - (os.getms() - start) / 1000)
  return ""
end

return AI
