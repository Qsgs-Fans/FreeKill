TestGameLogic = {}

function TestGameLogic:setup() InitRoom() end
function TestGameLogic:tearDown() ClearRoom() end

-- initialize与run略过

function TestGameLogic:testAssignRoles()
  local room = LRoom
  RunInRoom(function()
    GameLogic.assignRoles(room.logic)
  end)

  local roles = table.simpleClone(room.logic.role_table[#room.players])
  local rolesAssigned = table.map(room.players, function(p) return p.role end)
  local rolesAssigned2 = table.map(ClientInstance.players, function(p) return p.role end)

  lu.assertItemsEquals(roles, rolesAssigned)
  lu.assertItemsEquals(roles, rolesAssigned2)

  for _, p in ipairs(room.players) do
    if p.role == "lord" then
      lu.assertTrue(p.role_shown)
    else
      lu.assertNotTrue(p.role_shown)
    end
  end

  for _, p in ipairs(ClientInstance.players) do
    if p.role == "lord" then
      lu.assertTrue(p.role_shown)
    else
      lu.assertNotTrue(p.role_shown)
    end
  end
end

-- chooseGenerals

function TestGameLogic:testBuildPlayerCircle()
  for _, room in ipairs{LRoom, ClientInstance} do
    lu.assertIsTrue(#room.players == #room.alive_players)
    for i, p in ipairs(room.players) do
      if i == #room.players then
        lu.assertIsTrue(p.next == room.players[1])
      else
        lu.assertIsTrue(p.next == room.players[i + 1])
      end
    end
  end
end

function TestGameLogic:testAddTriggerSkill()
  local room = LRoom
  -- 已经add过了GameRule 测试一下覆盖到的分支
  lu.assertTableContains(room.logic.skills, "game_rule")

  -- TODO: 其余assert, 其余传参以达成分支覆盖
end

function TestGameLogic:testTrigger()
  local room = LRoom
  local logic = room.logic
end
