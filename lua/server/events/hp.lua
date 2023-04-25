-- SPDX-License-Identifier: GPL-3.0-or-later

local damage_nature_table = {
  [fk.NormalDamage] = "normal_damage",
  [fk.FireDamage] = "fire_damage",
  [fk.ThunderDamage] = "thunder_damage",
  [fk.IceDamage] = "ice_damage",
}

local function sendDamageLog(room, damageStruct)
  if damageStruct.from then
    room:sendLog{
      type = "#Damage",
      to = {damageStruct.from.id},
      from = damageStruct.to.id,
      arg = damageStruct.damage,
      arg2 = damage_nature_table[damageStruct.damageType],
    }
  else
    room:sendLog{
      type = "#DamageWithNoFrom",
      from = damageStruct.to.id,
      arg = damageStruct.damage,
      arg2 = damage_nature_table[damageStruct.damageType],
    }
  end
  room:sendLogEvent("Damage", {
    to = damageStruct.to.id,
    damageType = damage_nature_table[damageStruct.damageType],
    damageNum = damageStruct.damage,
  })
end

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
    damageEvent = damageStruct,
  }

  if self.logic:trigger(fk.BeforeHpChanged, player, data) then
    self.logic:breakEvent(false)
  end

  assert(not (data.reason == "recover" and data.num < 0))
  player.hp = math.min(player.hp + data.num, player.maxHp)
  self:broadcastProperty(player, "hp")

  if reason == "damage" then
    sendDamageLog(self, damageStruct)
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
    if num < 0 and not data.preventDying then
      ---@type DyingStruct
      local dyingStruct = {
        who = player.id,
        damage = damageStruct,
      }
      self:enterDying(dyingStruct)
    end
  elseif player.dying then
    player.dying = false
    self:broadcastProperty(player, "dying")
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

  -- 先扣减护甲，再扣体力值
  local shield_to_lose = math.min(damageStruct.damage, damageStruct.to.shield)
  self:changeShield(damageStruct.to, -shield_to_lose)

  if shield_to_lose < damageStruct.damage then
    if not self:changeHp(
      damageStruct.to,
      shield_to_lose - damageStruct.damage,
      "damage",
      damageStruct.skillName,
      damageStruct) then
      self.logic:breakEvent(false)
    end
  else
    sendDamageLog(self, damageStruct)
  end

  stages = {
    {fk.Damage, damageStruct.from},
    {fk.Damaged, damageStruct.to},
    {fk.DamageFinished, damageStruct.to},
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
  if player.maxHp == 0 then
    self:killPlayer({ who = player.id })
  end

  local diff = player.hp - player.maxHp
  if diff > 0 then
    if not self:changeHp(player, -diff) then
      player.hp = player.hp - diff
    end
  end

  self.logic:trigger(fk.MaxHpChanged, player, { num = num })
  return true
end
