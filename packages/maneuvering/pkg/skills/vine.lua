local skill = fk.CreateSkill {
  name = "#vine_skill",
  attached_equip = "vine",
  frequency = Skill.Compulsory,
}

skill:addEffect(fk.PreCardEffect, {
  can_trigger = function(self, event, target, player, data)
    return data.to == player and player:hasSkill(skill.name) and
      table.contains({"slash", "savage_assault", "archery_attack"}, data.card.name)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:sendLog{
      type = "#InvokeSkill",
      from = player.id,
      arg = self.name,
    }
    room:broadcastPlaySound("./packages/maneuvering/audio/card/vine")
    room:setEmotion(player, "./packages/maneuvering/image/anim/vine")
    return true
  end,
})

skill:addEffect(fk.DamageInflicted, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and data.damageType == fk.FireDamage
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:sendLog{
      type = "#InvokeSkill",
      from = player.id,
      arg = self.name,
    }
    room:broadcastPlaySound("./packages/maneuvering/audio/card/vineburn")
    room:setEmotion(player, "./packages/maneuvering/image/anim/vineburn")
    data.damage = data.damage + 1
  end,
})

return skill
