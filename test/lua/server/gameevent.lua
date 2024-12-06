
TestGameEvent = {}

-- setup和tearDown会在每个单独的测试函数启动与结束调用.
-- 可以联想setupClass和tearDownClass.
function TestGameEvent:setup() InitRoom() end

function TestGameEvent:testBasic()
  local room = LRoom
  local me, comp2, comp3, comp4, comp5, comp6, comp7, comp8 =
    room.players[1], room.players[2], room.players[3], room.players[4],
    room.players[5], room.players[6], room.players[7], room.players[8]

  ---@type DamageStruct
  local dmg = {
    from = me,
    to = comp2,
    damage = 1
  }

  RunInRoom(function()
    room:damage(dmg)
  end)
end

function TestGameEvent:tearDown() ClearRoom() end
