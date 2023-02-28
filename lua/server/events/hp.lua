GameEvent.functions[GameEvent.ChangeHp] = function(self)
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

GameEvent.functions[GameEvent.Damage] = function(self)
  local damageStruct = table.unpack(self.data)
  local self = self.room
  if damageStruct.damage < 1 then
    return false
  end
  damageStruct.damageType = damageStruct.damageType or fk.NormalDamage

  if damageStruct.from and not damageStruct.from:isAlive() then
    damageStruct.from = nil
  end

  assert(damageStruct.to:isInstanceOf(ServerPlayer))

  local stages = {
    {fk.PreDamage, damageStruct.from},
    {fk.DamageCaused, damageStruct.from},
    {fk.DamageInflicted, damageStruct.to},
  }

  for _, struct in ipairs(stages) do
    local event, player = table.unpack(struct)
    if self.logic:trigger(event, player, damageStruct) or damageStruct.damage < 1 then
      self.logic:breakEvent(false)
    end

    assert(damageStruct.to:isInstanceOf(ServerPlayer))
  end

  if not damageStruct.to:isAlive() then
    return false
  end

  if not self:changeHp(damageStruct.to, -damageStruct.damage, "damage", damageStruct.skillName, damageStruct) then
    self.logic:breakEvent(false)
  end

  stages = {
    {fk.Damage, damageStruct.from},
    {fk.Damaged, damageStruct.to},
    {fk.DamageFinished, damageStruct.from},
  }

  for _, struct in ipairs(stages) do
    local event, player = table.unpack(struct)
    self.logic:trigger(event, player, damageStruct)
  end

  return true
end

GameEvent.functions[GameEvent.LoseHp] = function(self)
  local player, num, skillName = table.unpack(self.data)
  local self = self.room
  if num == nil then
    num = 1
  elseif num < 1 then
    return false
  end

  ---@type HpLostData
  local data = {
    num = num,
    skillName = skillName,
  }
  if self.logic:trigger(fk.PreHpLost, player, data) or data.num < 1 then
    self.logic:breakEvent(false)
  end

  if not self:changeHp(player, -num, "loseHp", skillName) then
    self.logic:breakEvent(false)
  end

  self.logic:trigger(fk.HpLost, player, data)
  return true
end

GameEvent.functions[GameEvent.Recover] = function(self)
  local recoverStruct = table.unpack(self.data)
  local self = self.room
  if recoverStruct.num < 1 then
    return false
  end

  local who = recoverStruct.who
  if self.logic:trigger(fk.PreHpRecover, who, recoverStruct) or recoverStruct.num < 1 then
    self.logic:breakEvent(false)
  end

  if not self:changeHp(who, recoverStruct.num, "recover", recoverStruct.skillName) then
    self.logic:breakEvent(false)
  end

  self.logic:trigger(fk.HpRecover, who, recoverStruct)
  return true
end

GameEvent.functions[GameEvent.ChangeMaxHp] = function(self)
  local player, num = table.unpack(self.data)
  local self = self.room
  if num == 0 then
    return false
  end

  player.maxHp = math.max(player.maxHp + num, 0)
  self:broadcastProperty(player, "maxHp")
  local diff = player.hp - player.maxHp
  if diff > 0 then
    if not self:changeHp(player, -diff) then
      player.hp = player.hp - diff
    end
  end

  if player.maxHp == 0 then
    self:killPlayer({ who = player.id })
  end

  self.logic:trigger(fk.MaxHpChanged, player, { num = num })
  return true
end
