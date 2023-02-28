GameEvent.functions[GameEvent.ChangeHp] = {
  -- main func
  function(self)
    local player, num, reason, skillName, damageStruct = table.unpack(self.data)
    local self = self.room
    if num == 0 then
      return false
    end
    assert(reason == nil or table.contains({ "loseHp", "damage", "recover" }, reason))

    ---@type HpChangedData
    local data = {
      num = num,
      reason = reason,
      skillName = skillName,
    }

    if self.logic:trigger(fk.BeforeHpChanged, player, data) then
      self.logic:breakEvent(false)
    end

    assert(not (data.reason == "recover" and data.num < 0))
    player.hp = math.min(player.hp + data.num, player.maxHp)
    self:broadcastProperty(player, "hp")

    if reason == "damage" then
      local damage_nature_table = {
        [fk.NormalDamage] = "normal_damage",
        [fk.FireDamage] = "fire_damage",
        [fk.ThunderDamage] = "thunder_damage",
      }
      if damageStruct.from then
        self:sendLog{
          type = "#Damage",
          to = {damageStruct.from.id},
          from = player.id,
          arg = 0 - num,
          arg2 = damage_nature_table[damageStruct.damageType],
        }
      else
        self:sendLog{
          type = "#DamageWithNoFrom",
          from = player.id,
          arg = 0 - num,
          arg2 = damage_nature_table[damageStruct.damageType],
        }
      end
      self:sendLogEvent("Damage", {
        to = player.id,
        damageType = damage_nature_table[damageStruct.damageType],
        damageNum = damageStruct.damage,
      })
    elseif reason == "loseHp" then
      self:sendLog{
        type = "#LoseHP",
        from = player.id,
        arg = 0 - num,
      }
      self:sendLogEvent("LoseHP", {})
    elseif reason == "recover" then
      self:sendLog{
        type = "#HealHP",
        from = player.id,
        arg = num,
      }
    end

    self:sendLog{
      type = "#ShowHPAndMaxHP",
      from = player.id,
      arg = player.hp,
      arg2 = player.maxHp,
    }

    self.logic:trigger(fk.HpChanged, player, data)

    if player.hp < 1 then
      if num < 0 then
        ---@type DyingStruct
        local dyingStruct = {
          who = player.id,
          damage = damageStruct,
        }
        self:enterDying(dyingStruct)
      end
    elseif player.dying then
      player.dying = false
    end

    return true
  end

  -- clear func, leave it to nil
}
