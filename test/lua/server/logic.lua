-- 针对 lua/server/gamelogic.lua 以及 GameEvent 的测试

local croom
TestGameLogic = {
  setup = function()
    croom = fk.Room:new()
    croom.players = {
      fk.ServerPlayer:new(),
      fk.ServerPlayer:new(),
      fk.ServerPlayer:new(),
      fk.ServerPlayer:new(),
      fk.ServerPlayer:new(),
    }
  end,

  testTrigger = function()
    fk.roomtest(croom, function(room)
      local p = room.alive_players[1]
      p:drawCards(1)
    end)
  end,

  tearDown = function() croom = nil end
}
