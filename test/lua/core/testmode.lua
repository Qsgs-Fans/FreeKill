---@diagnostic disable

local testmode = GameMode:new("testmode", 2, 8)
testmode.logic = function()
  ---@type GameLogic
  local l = GameLogic:subclass("testmodelogic")
  --[[
  function l:chooseGenerals()
    local room = self.room
    room.current = room.players[1]
    for _, p in ipairs(room.players) do
      room:setPlayerGeneral(p, "blank_shibing")
    end
  end
  --]]
  function l:action()
    if type(self.room.action) == "function" then
      self.room.action()
    end
  end
  return l
end
Fk.game_modes["testmode"] = testmode
Fk:loadDisabled()
