-- SPDX-License-Identifier: GPL-3.0-or-later

---@class HpEventWrappers: Object
local HpEventWrappers = {} -- mixin

---@return boolean
local function exec(tp, ...)
  local event = tp:create(...)
  local _, ret = event:exec()
  return ret
end

-- local damage_nature_table = {
--   [fk.NormalDamage] = "normal_damage",
--   [fk.FireDamage] = "fire_damage",
--   [fk.ThunderDamage] = "thunder_damage",
--   [fk.IceDamage] = "ice_damage",
-- }

local function sendDamageLog(room, damageStruct)
  local damageName = Fk:getDamageNatureName(damageStruct.damageType)
  if damageStruct.from then
    room:sendLog{
      type = "#Damage",
      to = {damageStruct.from.id},
      from = damageStruct.to.id,
      arg = damageStruct.damage,
      arg2 = damageName,
    }
  else
    room:sendLog{
      type = "#DamageWithNoFrom",
      from = damageStruct.to.id,
      arg = damageStruct.damage,
      arg2 = damageName,
    }
  end
  room:sendLogEvent("Damage", {
    to = damageStruct.to.id,
    damageType = damageName,
    damageNum = damageStruct.damage,
  })
end

---@class GameEvent.ChangeHp : GameEvent
local ChangeHp = GameEvent:subclass("GameEvent.ChangeHp")
function ChangeHp:main()
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

  if reason == "damage" then
    if damageStruct then
      if Fk:canChain(damageStruct.damageType) and damageStruct.to.chained then
        damageStruct.to:setChainState(false)
        if not damageStruct.chain then
          damageStruct.beginnerOfTheDamage = true
          damageStruct.chain_table = table.filter(room:getOtherPlayers(damageStruct.to), function(p)
            return p.chained
          end)
        end
      end
    end
    data.shield_lost = math.min(-num, player.shield)
    data.num = num + data.shield_lost
  end

  if logic:trigger(fk.BeforeHpChanged, player, data) then
    logic:breakEvent(false)
  end

  if reason == "damage" and data.shield_lost > 0 and not damageStruct.isVirtualDMG then
    room:changeShield(player, -data.shield_lost)
  end

  if reason == "damage" then
    sendDamageLog(room, damageStruct)
  end

  if not (reason == "damage" and (data.num == 0 or damageStruct.isVirtualDMG)) then
    assert(not (data.reason == "recover" and data.num < 0))
    player.hp = math.min(player.hp + data.num, player.maxHp)
    room:broadcastProperty(player, "hp")

    if reason == "loseHp" then
      room:sendLog{
        type = "#LoseHP",
        from = player.id,
        arg = 0 - data.num,
      }
      room:sendLogEvent("LoseHP", {})
    elseif reason == "recover" then
      room:sendLog{
        type = "#HealHP",
        from = player.id,
        arg = data.num,
      }
    end

    room:sendLog{
      type = "#ShowHPAndMaxHP",
      from = player.id,
      arg = player.hp,
      arg2 = player.maxHp,
    }
  end

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

--- 改变一名玩家的体力。
---@param player ServerPlayer @ 玩家
---@param num integer @ 变化量
---@param reason? string @ 原因
---@param skillName? string @ 技能名
---@param damageStruct? DamageStruct @ 伤害数据
---@return boolean
function HpEventWrappers:changeHp(player, num, reason, skillName, damageStruct)
  return exec(ChangeHp, player, num, reason, skillName, damageStruct)
end

---@class GameEvent.Damage : GameEvent
local Damage = GameEvent:subclass("GameEvent.Damage")
function Damage:main()
  local damageStruct = table.unpack(self.data)
  local room = self.room
  local logic = room.logic

  if not damageStruct.chain and logic:damageByCardEffect(false) then
    local cardEffectData = logic:getCurrentEvent():findParent(GameEvent.CardEffect)
    if cardEffectData then
      local cardEffectEvent = cardEffectData.data[1]
      damageStruct.damage = damageStruct.damage + (cardEffectEvent.additionalDamage or 0)
      if damageStruct.from and cardEffectEvent.from == damageStruct.from.id then
        damageStruct.by_user = true
      end
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

  local stages = {}

  if not damageStruct.isVirtualDMG then
    stages = {
      { fk.PreDamage, "from"},
      { fk.DamageCaused, "from" },
      { fk.DamageInflicted, "to" },
    }
  end

  for _, struct in ipairs(stages) do
    local event, player = table.unpack(struct)
    if logic:trigger(event, damageStruct[player], damageStruct) or damageStruct.damage < 1 then
      logic:breakEvent(false)
    end

    assert(damageStruct.to:isInstanceOf(ServerPlayer))
  end

  if damageStruct.to.dead then
    return false
  end

  damageStruct.dealtRecorderId = room.logic.specific_events_id[GameEvent.Damage]
  room.logic.specific_events_id[GameEvent.Damage] = room.logic.specific_events_id[GameEvent.Damage] + 1

  if damageStruct.card and damageStruct.damage > 0 then
    local parentUseData = logic:getCurrentEvent():findParent(GameEvent.UseCard)
    if parentUseData then
      local cardUseEvent = parentUseData.data[1]
      cardUseEvent.damageDealt = cardUseEvent.damageDealt or {}
      cardUseEvent.damageDealt[damageStruct.to.id] = (cardUseEvent.damageDealt[damageStruct.to.id] or 0) + damageStruct.damage
    end
  end

  if not room:changeHp(
    damageStruct.to,
    -damageStruct.damage,
    "damage",
    damageStruct.skillName,
    damageStruct) then
    logic:breakEvent(false)
  end


  stages = {
    {fk.Damage, "from"},
    {fk.Damaged, "to"},
  }

  for _, struct in ipairs(stages) do
    local event, player = table.unpack(struct)
    logic:trigger(event, damageStruct[player], damageStruct)
  end

  return true
end

function Damage:exit()
  local room = self.room
  local logic = room.logic
  local damageStruct = self.data[1]

  logic:trigger(fk.DamageFinished, damageStruct.to, damageStruct)

  if damageStruct.chain_table and #damageStruct.chain_table > 0 then
    damageStruct.chain_table = table.filter(damageStruct.chain_table, function(p)
      return p:isAlive() and p.chained
    end)
    for _, p in ipairs(damageStruct.chain_table) do
      room:sendLog{
        type = "#ChainDamage",
        from = p.id
      }

      local dmg = {
        from = damageStruct.from,
        to = p,
        damage = damageStruct.damage,
        damageType = damageStruct.damageType,
        card = damageStruct.card,
        skillName = damageStruct.skillName,
        chain = true,
      }

      room:damage(dmg)
    end
  end
end

--- 根据伤害数据造成伤害。
---@param damageStruct DamageStruct
---@return boolean
function HpEventWrappers:damage(damageStruct)
  return exec(Damage, damageStruct)
end

---@class GameEvent.LoseHp : GameEvent
local LoseHp = GameEvent:subclass("GameEvent.LoseHp")
function LoseHp:main()
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

--- 令一名玩家失去体力。
---@param player ServerPlayer @ 玩家
---@param num integer @ 失去的数量
---@param skillName? string @ 技能名
---@return boolean
function HpEventWrappers:loseHp(player, num, skillName)
  return exec(LoseHp, player, num, skillName)
end

---@class GameEvent.Recover : GameEvent
local Recover = GameEvent:subclass("GameEvent.Recover")
function Recover:prepare()
  local recoverStruct = table.unpack(self.data) ---@type RecoverStruct
  local room = self.room
  local logic = room.logic

  local who = recoverStruct.who

  if who.maxHp - who.hp < 0 then
    return true
  end

end

function Recover:main()
  local recoverStruct = table.unpack(self.data) ---@type RecoverStruct
  local room = self.room
  local logic = room.logic

  if recoverStruct.card then
    local cardEffectData = logic:getCurrentEvent():findParent(GameEvent.CardEffect)
    if cardEffectData then
      local cardEffectEvent = cardEffectData.data[1]
      recoverStruct.num = recoverStruct.num + (cardEffectEvent.additionalRecover or 0)
    end
  end

  local who = recoverStruct.who

  if logic:trigger(fk.PreHpRecover, who, recoverStruct) then
    logic:breakEvent(false)
  end

  recoverStruct.num = math.min(recoverStruct.num, who.maxHp - who.hp)

  if recoverStruct.num < 1 then
    return false
  end

  if not room:changeHp(who, recoverStruct.num, "recover", recoverStruct.skillName) then
    logic:breakEvent(false)
  end

  logic:trigger(fk.HpRecover, who, recoverStruct)
  return true
end

--- 根据回复数据回复体力。
---@param recoverStruct RecoverStruct
---@return boolean
function HpEventWrappers:recover(recoverStruct)
  return exec(Recover, recoverStruct)
end

---@class GameEvent.ChangeMaxHp : GameEvent
local ChangeMaxHp = GameEvent:subclass("GameEvent.ChangeMaxHp")
function ChangeMaxHp:main()
  local player, num = table.unpack(self.data)
  local room = self.room

  ---@type MaxHpChangedData
  local data = {
    num = num,
  }

  if room.logic:trigger(fk.BeforeMaxHpChanged, player, data) or data.num == 0 then
    return false
  end

  num = data.num

  room:setPlayerProperty(player, "maxHp", math.max(player.maxHp + num, 0))
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

--- 改变一名玩家的体力上限。
---@param player ServerPlayer @ 玩家
---@param num integer @ 变化量
---@return boolean
function HpEventWrappers:changeMaxHp(player, num)
  return exec(ChangeMaxHp, player, num)
end

return { ChangeHp, Damage, LoseHp, Recover, ChangeMaxHp, HpEventWrappers }
