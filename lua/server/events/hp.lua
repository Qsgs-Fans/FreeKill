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
  local room = self.room
  local logic = room.logic
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

  if logic:trigger(fk.BeforeHpChanged, player, data) then
    logic:breakEvent(false)
  end

  assert(not (data.reason == "recover" and data.num < 0))
  player.hp = math.min(player.hp + data.num, player.maxHp)
  room:broadcastProperty(player, "hp")

  if reason == "damage" then
    sendDamageLog(room, damageStruct)
  elseif reason == "loseHp" then
    room:sendLog{
      type = "#LoseHP",
      from = player.id,
      arg = 0 - num,
    }
    room:sendLogEvent("LoseHP", {})
  elseif reason == "recover" then
    room:sendLog{
      type = "#HealHP",
      from = player.id,
      arg = num,
    }
  end

  room:sendLog{
    type = "#ShowHPAndMaxHP",
    from = player.id,
    arg = player.hp,
    arg2 = player.maxHp,
  }

  logic:trigger(fk.HpChanged, player, data)

  if player.hp < 1 then
    if num < 0 and not data.preventDying then
      ---@type DyingStruct
      local dyingStruct = {
        who = player.id,
        damage = damageStruct,
      }
      room:enterDying(dyingStruct)
    end
  elseif player.dying then
    player.dying = false
    room:broadcastProperty(player, "dying")
  end

  return true
end

GameEvent.functions[GameEvent.Damage] = function(self)
  local damageStruct = table.unpack(self.data)
  local room = self.room
  local logic = room.logic
  if damageStruct.card and damageStruct.skillName == damageStruct.card.name .. "_skill" and not damageStruct.chain then
    local cardEffectData = logic:getCurrentEvent():findParent(GameEvent.CardEffect)
    if cardEffectData then
      local cardEffectEvent = cardEffectData.data[1]
      damageStruct.damage = damageStruct.damage + (cardEffectEvent.additionalDamage or 0)
    end
  end

  if damageStruct.damage < 1 then
    return false
  end
  damageStruct.damageType = damageStruct.damageType or fk.NormalDamage

  if damageStruct.from and damageStruct.from.dead then
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
    if logic:trigger(event, player, damageStruct) or damageStruct.damage < 1 then
      logic:breakEvent(false)
    end

    assert(damageStruct.to:isInstanceOf(ServerPlayer))
  end

  if damageStruct.to.dead then
    return false
  end

  if damageStruct.card and damageStruct.damage > 0 then
    local parentUseData = logic:getCurrentEvent():findParent(GameEvent.UseCard)
    if parentUseData then
      local cardUseEvent = parentUseData.data[1]
      cardUseEvent.damageDealt = cardUseEvent.damageDealt or {}
      cardUseEvent.damageDealt[damageStruct.to.id] = (cardUseEvent.damageDealt[damageStruct.to.id] or 0) + damageStruct.damage
    end
  end

  if damageStruct.damageType ~= fk.NormalDamage and damageStruct.to.chained then
    damageStruct.beginnerOfTheDamage = true
    damageStruct.to:setChainState(false)
  end

  -- 先扣减护甲，再扣体力值
  local shield_to_lose = math.min(damageStruct.damage, damageStruct.to.shield)
  room:changeShield(damageStruct.to, -shield_to_lose)

  if shield_to_lose < damageStruct.damage then
    if not room:changeHp(
      damageStruct.to,
      shield_to_lose - damageStruct.damage,
      "damage",
      damageStruct.skillName,
      damageStruct) then
      logic:breakEvent(false)
    end
  else
    sendDamageLog(room, damageStruct)
  end

  stages = {
    {fk.Damage, damageStruct.from},
    {fk.Damaged, damageStruct.to},
    {fk.DamageFinished, damageStruct.to},
  }

  for _, struct in ipairs(stages) do
    local event, player = table.unpack(struct)
    logic:trigger(event, player, damageStruct)
  end

  return true
end

GameEvent.exit_funcs[GameEvent.Damage] = function(self)
  local room = self.room
  local logic = room.logic
  local damageStruct = self.data[1]

  logic:trigger(fk.DamageFinished, damageStruct.to, damageStruct)

  if damageStruct.beginnerOfTheDamage and not damageStruct.chain then
    local targets = table.filter(room:getOtherPlayers(damageStruct.to), function(p)
      return p.chained
    end)
    for _, p in ipairs(targets) do
      room:sendLog{
        type = "#ChainDamage",
        from = p.id
      }
      local dmg = table.simpleClone(damageStruct)
      dmg.to = p
      dmg.chain = true
      room:damage(dmg)
    end
  end
end

GameEvent.functions[GameEvent.LoseHp] = function(self)
  local player, num, skillName = table.unpack(self.data)
  local room = self.room
  local logic = room.logic

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
  if logic:trigger(fk.PreHpLost, player, data) or data.num < 1 then
    logic:breakEvent(false)
  end

  if not room:changeHp(player, -data.num, "loseHp", skillName) then
    logic:breakEvent(false)
  end

  logic:trigger(fk.HpLost, player, data)
  return true
end

GameEvent.functions[GameEvent.Recover] = function(self)
  local recoverStruct = table.unpack(self.data)
  local room = self.room
  local logic = room.logic

  if recoverStruct.card then
    local cardEffectData = logic:getCurrentEvent():findParent(GameEvent.CardEffect)
    if cardEffectData then
      local cardEffectEvent = cardEffectData.data[1]
      recoverStruct.num = recoverStruct.num + (cardEffectEvent.additionalRecover or 0)
    end
  end

  if recoverStruct.num < 1 then
    return false
  end

  local who = recoverStruct.who

  if logic:trigger(fk.PreHpRecover, who, recoverStruct) or recoverStruct.num < 1 then
    logic:breakEvent(false)
  end

  if not room:changeHp(who, recoverStruct.num, "recover", recoverStruct.skillName) then
    logic:breakEvent(false)
  end

  logic:trigger(fk.HpRecover, who, recoverStruct)
  return true
end

GameEvent.functions[GameEvent.ChangeMaxHp] = function(self)
  local player, num = table.unpack(self.data)
  local room = self.room
  if num == 0 then
    return false
  end

  player.maxHp = math.max(player.maxHp + num, 0)
  room:broadcastProperty(player, "maxHp")
  room:sendLogEvent("ChangeMaxHp", {
    player = player.id,
    num = num,
  })
  room:sendLog{
    type = num > 0 and "#HealMaxHP" or "#LoseMaxHP",
    from = player.id,
    arg = num > 0 and num or - num,
  }
  if player.maxHp == 0 then
    player.hp = 0
    room:broadcastProperty(player, "hp")
    room:sendLog{
      type = "#ShowHPAndMaxHP",
      from = player.id,
      arg = 0,
      arg2 = 0,
    }
    room:killPlayer({ who = player.id })
    return false
  end

  local diff = player.hp - player.maxHp
  if diff > 0 then
    if not room:changeHp(player, -diff) then
      player.hp = player.hp - diff
    end
  end

  room:sendLog{
    type = "#ShowHPAndMaxHP",
    from = player.id,
    arg = player.hp,
    arg2 = player.maxHp,
  }

  room.logic:trigger(fk.MaxHpChanged, player, { num = num })
  return true
end
