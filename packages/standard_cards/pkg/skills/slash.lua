local skill = fk.CreateSkill {
  name = "slash_skill",
}

skill:addEffect("cardskill", {
  prompt = function(self, player, selected_cards)
    local slash = Fk:cloneCard("slash")
    slash:addSubcards(selected_cards)
    local max_num = self:getMaxTargetNum(player, slash) -- halberd
    if max_num > 1 then
      local num = #table.filter(Fk:currentRoom().alive_players, function (p)
        return p ~= player and not player:isProhibited(p, slash)
      end)
      max_num = math.min(num, max_num)
    end
    return max_num > 1 and "#slash_skill_multi:::" .. max_num or "#slash_skill"
  end,
  max_phase_use_time = 1,
  target_num = 1,
  can_use = function(self, player, card, extra_data)
    if player:prohibitUse(card) then return end
    return (extra_data and extra_data.bypass_times) or player.phase ~= Player.Play or
      table.find(Fk:currentRoom().alive_players, function(p)
        return self:targetFilter(player, p, {}, {}, card, extra_data)
      end) ~= nil
  end,
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    return to_select ~= player and
      not (not (extra_data and extra_data.bypass_distances) and not self:withinDistanceLimit(player, true, card, to_select))
  end,
  target_filter = function(self, player, to_select, selected, _, card, extra_data)
    if not Util.CardTargetFilter(self, player, to_select, selected, _, card, extra_data) then return end
    return self:modTargetFilter(player, to_select, selected, card, extra_data) and
      (
        #selected > 0 or
        player.phase ~= Player.Play or
        (extra_data and extra_data.bypass_times) or
        self:withinTimesLimit(player, Player.HistoryPhase, card, "slash", to_select)
      )
  end,
  on_effect = function(self, room, effect)
    if not effect.to.dead then
      room:damage({
        from = effect.from,
        to = effect.to,
        card = effect.card,
        damage = 1,
        damageType = fk.NormalDamage,
        skillName = skill.name
      })
    end
  end,
})

skill:addAI({
  on_effect = function(self, logic, effect)
    logic:damage({
      from = effect.from,
      to = effect.to,
      card = effect.card,
      damage = 1,
      damageType = fk.NormalDamage,
      skillName = skill.name
    })
  end,
}, "__card_skill")

skill:addTest(function(room, me)
  local slash = Fk:getCardById(1)
  local comp2 = room.players[2]

  -- 简单测试on_effect
  FkTest.setNextReplies(comp2, { "" })
  FkTest.runInRoom(function()
    room:useCard {
      from = me,
      tos = { comp2 },
      card = slash,
    }
  end)
  lu.assertEquals(comp2.hp, 3)

  -- 然后在摸牌阶段中断，并来客户端进行简单测试
  FkTest.setRoomBreakpoint(me, "PlayCard")
  FkTest.runInRoom(function()
    room:obtainCard(me, slash)
    Request:new(me, "PlayCard"):ask()
  end)

  local handler = ClientInstance.current_request_handler --[[ @as ReqPlayCard ]]
  -- 简单测试can_use：能用就行
  lu.assertIsTrue(handler:cardValidity(slash.id))
  -- 简单测试target_filter：应该只选的到攻击范围内的也就是2和8号位
  handler:selectCard(slash.id, { selected = true })
  lu.assertEquals(table.map(room:getOtherPlayers(me), function(p)
    return not not handler:targetValidity(p.id)
  end), { true, false, false, false, false, false, true })
end)

return skill
