local vineSkill = fk.CreateSkill {
  name = "#vine_skill",
  tags = { Skill.Compulsory },
  attached_equip = "vine",
}

vineSkill:addEffect(fk.PreCardEffect, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return data.to == player and player:hasSkill(vineSkill.name) and
      table.contains({"slash", "savage_assault", "archery_attack"}, data.card.name)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:broadcastPlaySound("./packages/maneuvering/audio/card/vine")
    room:setEmotion(player, "./packages/maneuvering/image/anim/vine")
    data.nullified = true
  end,
})

vineSkill:addEffect(fk.DamageInflicted, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(vineSkill.name) and data.damageType == fk.FireDamage
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:broadcastPlaySound("./packages/maneuvering/audio/card/vineburn")
    room:setEmotion(player, "./packages/maneuvering/image/anim/vineburn")
    data:changeDamage(1)
  end,
})

vineSkill:addTest(function (room, me)
  local card = room:printCard("vine")
  local comp2 = room.players[2]
  FkTest.runInRoom(function ()
    room:useCard{
      from = me,
      tos = {me},
      card = card,
    }
    room:useVirtualCard("slash", nil, comp2, me)
    room:useVirtualCard("archery_attack", nil, comp2, me)
    room:useVirtualCard("savage_assault", nil, comp2, me)
  end)
  lu.assertEquals(me.hp, 4)
  FkTest.runInRoom(function ()
    room:useVirtualCard("fire__slash", nil, comp2, me)
  end)
  lu.assertEquals(me.hp, 2)
end)

return vineSkill
