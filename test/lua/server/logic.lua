-- 针对 lua/server/gamelogic.lua 以及 GameEvent 的测试

local croom
_TestGameLogic = {
  setup = function()
    croom = fk.Room:new()
    croom.players = {
      fk.ServerPlayer:new(1),
      fk.ServerPlayer:new(2),
      fk.ServerPlayer:new(3),
      fk.ServerPlayer:new(4),
      fk.ServerPlayer:new(5),
    }
  end,

  testTrigger = function()
    ---@param room Room
    fk.roomtest(croom, function(room)
      local logic = room.logic
      local p = room:getPlayerById(1)
      room:handleAddLoseSkills(p, table.concat({
        "luoyi", "wansha", "yaoyi", --"dili",
      }, "|"))

      logic:trigger(fk.GamePrepared)
      GameEvent(GameEvent.DrawInitial):exec()
      GameEvent(GameEvent.Round):exec()

      -- DMG test
      local victim = room.alive_players[2]
      room:damage{ from = p, to = victim, damage = 20 }
      room:damage{ to = p, from = victim, damage = 20 }
    end)
  end,

  tearDown = function() croom = nil end
}
