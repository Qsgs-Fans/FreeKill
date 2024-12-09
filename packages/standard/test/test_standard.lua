TestStandard = { setup = InitRoom, tearDown = ClearRoom }

function TestStandard:testJianxiong()
  local room = LRoom
  local me, comp2 = room.players[1], room.players[2]
  RunInRoom(function() room:handleAddLoseSkills(me, "jianxiong") end)

  local slash = Fk:getCardById(1)
  SetNextReplies(me, { "__cancel", "1" })
  RunInRoom(function()
    room:useCard{
      from = comp2.id,
      tos = { { me.id } },
      card = slash,
    }
  end)
  p(me:toJsonObject())
end
