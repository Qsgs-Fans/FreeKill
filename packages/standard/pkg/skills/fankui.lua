local fankui = fk.CreateSkill({
  name = "fankui",
})

fankui:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(fankui.name)) then return end
    if data.from and not data.from.dead then
      if data.from == player then
        return #player:getCardIds("e") > 0
      else
        return not data.from:isNude()
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    local flag =  from == player and "e" or "he"
    local card = room:askForCardChosen(player, from, flag, fankui.name)
    room:obtainCard(player.id, card, false, fk.ReasonPrey)
  end
})

fankui:addTest(function(room, me)
  local comp2 = room.players[2] ---@type ServerPlayer, ServerPlayer
  FkTest.runInRoom(function() room:handleAddLoseSkills(me, "fankui") end)

  -- 空牌的情况
  local slash = Fk:getCardById(1)
  FkTest.setNextReplies(me, { "__cancel" })
  FkTest.runInRoom(function()
    room:useCard{
      from = comp2,
      tos = { me },
      card = slash,
    }
  end)
  lu.assertEquals(#me:getCardIds("h"), 0)

  -- 有牌的情况
  FkTest.setNextReplies(me, { "__cancel", "1", "3" })
  FkTest.runInRoom(function()
    room:obtainCard(comp2, { 3 })
    room:useCard{
      from = comp2,
      tos = { me },
      card = slash,
    }
  end)
  lu.assertEquals(me:getCardIds("h")[1], 3)
end)

return fankui
