
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

  --- 测试用例1：司马懿先生可以用仁王盾改判吗？
  RunInRoom(function()
    local cards = {}
    local targets = {"slash", "jink", "nioh_shield", "dilu"}
    local shield
    for _, cid in ipairs(room.draw_pile) do
      local c = Fk:getCardById(cid)
      if table.contains(targets, c.name) then
        table.insert(cards, c)
        if c.name == "nioh_shield" then
          shield = cid
        end
        table.removeOne(targets, c.name)
      end
      if #targets == 0 then break end
    end
    if not shield then return error("no nioh?") end
    room:obtainCard(me, cards)
    room:useCard{
      from = me.id,
      tos = {{me.id}},
      card = Fk:getCardById(shield)
    }
    room:changeHero(me, "simayi")
    for _, c in ipairs(me:getCardIds("he")) do
      local card = Fk:getCardById(c)
      local exp = Exppattern:Parse(".|.|.|hand")
      -- printf("%s's result: %q", tostring(card), exp:match(card))
      assert(c == shield or exp:match(card), string.format("no %s is allowed!", tostring(card)))
    end
  end)
end

function TestGameEvent:tearDown() ClearRoom() end
