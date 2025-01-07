
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

  --- 测试用例1：关于区域的pattern
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
    for _, c in ipairs(me:getCardIds("he")) do
      local card = Fk:getCardById(c)
      local exp = Exppattern:Parse(".|.|.|hand")
      -- printf("%s's result: %q", tostring(card), exp:match(card))
      -- assert(c == shield or exp:match(card), string.format("no %s is allowed!", tostring(card)))
      lu.assertTrue(c == shield or exp:match(card))
    end
  end)
end

function TestGameEvent:testMove()
  local room = LRoom
  local me, comp2, comp3, comp4, comp5, comp6, comp7, comp8 = ---@type ServerPlayer
    room.players[1], room.players[2], room.players[3], room.players[4],
    room.players[5], room.players[6], room.players[7], room.players[8]

  --- 测试用例1：通常移动
  RunInRoom(function()
    me:drawCards(1)
    lu.assertEquals(me:getHandcardNum(), 1)

    local card = me:getCardIds("h")[1]
    room:obtainCard(comp2, card)
    lu.assertEquals(me:getHandcardNum(), 0)
    lu.assertEquals(comp2:getCardIds("h")[1], card)
  end)

  --- 测试用例2：作死级移动
  RunInRoom(function()
    local top = room.draw_pile[1]
    local another = top // 2

    --- 试图直接控顶
    room:moveCardTo(another, Card.DrawPile)
    lu.assertEquals(room.draw_pile[1], another)
    lu.assertEquals(room.draw_pile[2], top)
  end)
end

function TestGameEvent:testJudge()
  local room = LRoom ---@type Room
  local me = ---@type ServerPlayer
    room.players[1]

  --- 测试用例1：判定
  RunInRoom(function()
    local card = Fk:getCardById(room.draw_pile[1])
    local judge = {
      who = me,
      reason = "lightning",
      pattern = ".|2~9|spade",
    }
    room:judge(judge)
    local result = judge.card
    lu.assertEquals(result.suit, card.suit)
    lu.assertEquals(result.color, card.color)
    lu.assertEquals(result.number, card.number)
  end)
end

function TestGameEvent:tearDown() ClearRoom() end
