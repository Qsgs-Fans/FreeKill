local skill = fk.CreateSkill {
  name = "peach_skill",
}

skill:addEffect("active", {
  prompt = "#peach_skill",
  mod_target_filter = function(self, player, to_select)
    return to_select:isWounded()
  end,
  can_use = Util.CanUseToSelf,
  on_use = function(self, room, use)
    if #use.tos == 0 then
      use:addTarget(use.from)
    end
  end,
  on_effect = function(self, room, effect)
    if effect.to:isWounded() and not effect.to.dead then
      room:recover{
        who = effect.to,
        num = 1,
        card = effect.card,
        recoverBy = effect.from,
        skillName = skill.name,
      }
    end
  end,
})

skill:addTest(function(room, me)
  local peach = room:printCard("peach")
  -- 客户端can_use测试：未受伤不能使用
  FkTest.runInRoom(function()
    room:obtainCard(me, peach)
    Request:new(me, "PlayCard"):ask()
  end)
  local handler = ClientInstance.current_request_handler --[[ @as ReqPlayCard ]]
  lu.assertIsFalse(handler:cardValidity(peach.id))

  -- 服务端on_effect测试：能正常回血
  FkTest.runInRoom(function()
    room:loseHp(me, 2)
    room:useCard {
      from = me,
      tos = { me },
      card = peach,
    }
  end)
  lu.assertEquals(me.hp, 3)

  -- 客户端can_use测试：已受伤能使用
  FkTest.setRoomBreakpoint(me, "PlayCard")
  FkTest.runInRoom(function()
    room:obtainCard(me, peach)
    Request:new(me, "PlayCard"):ask()
  end)
  handler = ClientInstance.current_request_handler --[[ @as ReqPlayCard ]]
  lu.assertIsTrue(handler:cardValidity(peach.id))
end)

return skill
