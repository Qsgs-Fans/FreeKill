local testmode = GameMode:new("testmode", 2, 8)
testmode.logic = function()
  ---@class TestModeGameLogic: GameLogic
  local l = GameLogic:subclass("TestModeGameLogic")
  function l:assignRoles()
    local room = self.room
    local n = #room.players
    local roles = self.role_table[n]
    -- table.shuffle(roles)
    local idlist = {1, 2, 3, 4, 5, 6, 7, 8}
    room.players = table.map(idlist, function(id) return room:getPlayerById(id) end)

    for i = 1, n do
      local p = room.players[i]
      p.role = roles[i]
      -- if p.role == "lord" then
      --   room:setPlayerProperty(p, "role_shown", true)
      -- end
      room:broadcastProperty(p, "role")
    end
  end
  function l:chooseGenerals()
    local room = self.room
    room.current = room.players[1]
    local glist = {"caocao", "sunquan", "liubei", "zhangfei",
      "ganning", "guanyu", "xuchu", "lvbu" }
    for i, p in ipairs(room.players) do
      room:prepareGeneral(p, glist[i])
    end
  end
  function l:prepareDrawPile()
    local room = self.room
    local gamemode = Fk.game_modes[room.settings.gameMode] or Fk.game_modes["aaa_role_mode"]
    local draw_pile = gamemode:buildDrawPile()
    room:prepareDrawPile(draw_pile)
    room:doBroadcastNotify("PrepareDrawPile", draw_pile)
  end
  function l:attachSkillToPlayers() end
  function l:action()
    while true do
      local fn = coroutine.yield("__handleRequest")
      if not fn then break end
      fn()
    end
  end
  return l
end
Fk.game_modes["testmode"] = testmode
Fk:loadDisabled()
