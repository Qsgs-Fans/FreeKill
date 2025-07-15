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

local function sendDamageLog(room, damageData)
  local damageName = Fk:getDamageNatureName(damageData.damageType)
  if damageData.from then
    room:sendLog{
      type = "#Damage",
      to = {damageData.from.id},
      from = damageData.to.id,
      arg = damageData.damage,
      arg2 = damageName,
    }
  else
    room:sendLog{
      type = "#DamageWithNoFrom",
      from = damageData.to.id,
      arg = damageData.damage,
      arg2 = damageName,
    }
  end
  room:sendLogEvent("Damage", {
    to = damageData.to.id,
    damageType = damageName,
    damageNum = damageData.damage,
  })
end

---@class GameEvent.ChangeHp : GameEvent
---@field public data HpChangedData
local ChangeHp = GameEvent:subclass("GameEvent.ChangeHp")

function ChangeHp:__tostring()
  local data = self.data
  return string.format("<ChangeHp %d : %s <= %s %s #%d>",
    data.num, data.who, data.reason, data.skillName, self.id)
end

function ChangeHp:main()
  local data = self.data
  local room = self.room
  local logic = room.logic
  local num = data.num
  local reason = data.reason
  local damageData = data.damageEvent
  if num == 0 then
    return false
  end
  assert(reason == nil or table.contains({ "loseHp", "damage", "recover" }, reason))

  if reason == "damage" then
    if damageData then
      if Fk:canChain(damageData.damageType) and damageData.to.chained then
        damageData.to:setChainState(false)
        if not damageData.chain then
          damageData.beginnerOfTheDamage = true
          damageData.chain_table = table.filter(room:getOtherPlayers(damageData.to), function(p)
            return p.chained
          end)
        end
      end
    end
    data.shield_lost = math.min(-num, data.who.shield)
    data.num = num + data.shield_lost
  end

  logic:trigger(fk.BeforeHpChanged, data.who, data)
  if data.num == 0 and data.shield_lost == 0 then
    data.prevented = true
  end
  if data.prevented then
    logic:breakEvent(false)
  end

  if reason == "damage" and data.shield_lost > 0 and not (damageData and damageData.isVirtualDMG) then
    room:changeShield(data.who, -data.shield_lost)
  end

  if reason == "damage" then
    sendDamageLog(room, damageData)
  end

  if not (reason == "damage" and (data.num == 0 or (damageData and damageData.isVirtualDMG))) then
    assert(not (data.reason == "recover" and data.num < 0))
    data.who.hp = math.min(data.who.hp + data.num, data.who.maxHp)
    room:broadcastProperty(data.who, "hp")

    if reason == "loseHp" then
      room:sendLog{
        type = "#LoseHP",
        from = data.who.id,
        arg = 0 - data.num,
      }
      room:sendLogEvent("LoseHP", {})
    elseif reason == "recover" then
      room:sendLog{
        type = "#HealHP",
        from = data.who.id,
        arg = data.num,
      }
    end

    room:sendLog{
      type = "#ShowHPAndMaxHP",
      from = data.who.id,
      arg = data.who.hp,
      arg2 = data.who.maxHp,
    }
  end

  logic:trigger(fk.HpChanged, data.who, data)

  if data.who.hp < 1 then
    if num < 0 and not data.preventDying then
      local dyingDataSpec = {
        who = data.who,
        damage = damageData,
        killer = damageData and damageData.from,
      }
      room:enterDying(dyingDataSpec)
    end
  elseif data.who.dying then
    data.who.dying = false
    room:broadcastProperty(data.who, "dying")
  end

  return true
end

--- 改变一名玩家的体力。
---@param player ServerPlayer @ 玩家
---@param num integer @ 变化量
---@param reason? string @ 原因
---@param skillName? string @ 技能名
---@param damageData? DamageData @ 伤害数据
---@return boolean
function HpEventWrappers:changeHp(player, num, reason, skillName, damageData)
  local data = HpChangedData:new{
    who = player,
    num = num,
    reason = reason,
    skillName = skillName,
    damageEvent = damageData
  }
  return exec(ChangeHp, data)
end

---@class GameEvent.Damage : GameEvent
---@field public data DamageData
local Damage = GameEvent:subclass("GameEvent.Damage")

function Damage:__tostring()
  local data = self.data
  return string.format("<Damage %d %s : %s <= %s #%d>",
    data.damage, Fk:getDamageNatureName(data.damageType), data.to, data.from, self.id)
end

function Damage:main()
  local damageData = self.data
  local room = self.room
  local logic = room.logic

  if not damageData.chain and logic:damageByCardEffect(false) then
    local cardEffectData = logic:getCurrentEvent():findParent(GameEvent.CardEffect)
    if cardEffectData then
      local cardEffectEvent = cardEffectData.data
      damageData.damage = damageData.damage + (cardEffectEvent.additionalDamage or 0)
      if damageData.from and cardEffectEvent.from == damageData.from then
        damageData.by_user = true
      end
    end
  end

  if damageData.damage < 1 then
    return false
  end
  damageData.damageType = damageData.damageType or fk.NormalDamage

  if damageData.from and damageData.from.dead then
    damageData.from = nil
  end

  assert(damageData.to:isInstanceOf(ServerPlayer))

  local stages = {}

  if not damageData.isVirtualDMG then
    stages = {
      { fk.PreDamage, "from"},
      { fk.DamageCaused, "from" },
      { fk.DetermineDamageCaused, "from" },
      { fk.DamageInflicted, "to" },
      { fk.DetermineDamageInflicted, "to" },
    }
  end

  for _, struct in ipairs(stages) do
    local event, player = table.unpack(struct)
    logic:trigger(event, damageData[player], damageData)
    if damageData.damage < 1 then
      damageData.prevented = true
    end
    if damageData.prevented then
      logic:breakEvent(false)
    end
    assert(damageData.to:isInstanceOf(ServerPlayer))
  end

  if damageData.to.dead then
    return false
  end

  damageData.dealtRecorderId = room.logic.specific_events_id[GameEvent.Damage]
  room.logic.specific_events_id[GameEvent.Damage] = room.logic.specific_events_id[GameEvent.Damage] + 1

  if damageData.card and damageData.damage > 0 then
    local parentUseData = logic:getCurrentEvent():findParent(GameEvent.UseCard)
    if parentUseData then
      local cardUseEvent = parentUseData.data
      cardUseEvent.damageDealt = cardUseEvent.damageDealt or {}
      cardUseEvent.damageDealt[damageData.to] = (cardUseEvent.damageDealt[damageData.to] or 0) + damageData.damage
    end
  end

  if not room:changeHp(damageData.to, -damageData.damage, "damage", damageData.skillName, damageData) then
    logic:breakEvent(false)
  end


  stages = {
    {fk.Damage, "from"},
    {fk.Damaged, "to"},
  }

  for _, struct in ipairs(stages) do
    local event, player = table.unpack(struct)
    logic:trigger(event, damageData[player], damageData)
  end

  return true
end

function Damage:exit()
  local room = self.room
  local logic = room.logic
  local damageData = self.data

  logic:trigger(fk.DamageFinished, damageData.to, damageData)

  if damageData.chain_table and #damageData.chain_table > 0 then
    for _, p in ipairs(damageData.chain_table) do
      if p:isAlive() and p.chained then
        room:sendLog{
          type = "#ChainDamage",
          from = p.id
        }

        local dmg = {
          from = damageData.from,
          to = p,
          damage = damageData.damage,
          damageType = damageData.damageType,
          card = damageData.card,
          skillName = damageData.skillName,
          chain = true,
        }

        room:damage(dmg)
      end
    end
  end
end

function Damage:desc()
  local damageData = self.data
  local ret = {
    type = damageData.from and "#GameEventDamage" or "#GameEventDamageNoFrom",
    from = damageData.to.id,
    arg = damageData.damage,
    arg2 = Fk:getDamageNatureName(damageData.damageType)
  }
  if damageData.from then ret.to = {damageData.from.id} end
  return ret
end

--- 根据伤害数据造成伤害。
---@param damageData DamageDataSpec
---@return boolean
function HpEventWrappers:damage(damageData)
  local data = DamageData:new(damageData)
  return exec(Damage, data)
end

---@class GameEvent.LoseHp : GameEvent
---@field public data HpLostData
local LoseHp = GameEvent:subclass("GameEvent.LoseHp")

function LoseHp:__tostring()
  local data = self.data
  return string.format("<LoseHp %d : %s #%d>",
    data.num, data.who, self.id)
end

function LoseHp:main()
  local data = self.data
  local room = self.room
  local logic = room.logic

  if data.num == nil then
    data.num = 1
  elseif data.num < 1 then
    return false
  end

  logic:trigger(fk.PreHpLost, data.who, data)
  if data.num < 1 then
    data.prevented = true
  end
  if data.prevented then
    logic:breakEvent(false)
  end

  if not room:changeHp(data.who, -data.num, "loseHp", data.skillName) then
    logic:breakEvent(false)
  end

  logic:trigger(fk.HpLost, data.who, data)
  return true
end

--- 令一名玩家失去体力。
---@param player ServerPlayer @ 玩家
---@param num integer @ 失去的数量
---@param skillName? string @ 技能名
---@return boolean
function HpEventWrappers:loseHp(player, num, skillName)
  local data = HpLostData:new{
    who = player,
    num = num,
    skillName = skillName,
  }
  return exec(LoseHp, data)
end

---@class GameEvent.Recover : GameEvent
---@field public data RecoverData
local Recover = GameEvent:subclass("GameEvent.Recover")

function Recover:__tostring()
  local data = self.data
  return string.format("<Recover %d : %s <= %s #%d>",
    data.num, data.who, data.recoverBy, self.id)
end

function Recover:prepare()
  local recoverData = self.data
  -- local room = self.room
  -- local logic = room.logic

  local who = recoverData.who

  if who.maxHp - who.hp < 0 then
    return true
  end

end

function Recover:main()
  local recoverData = self.data
  local room = self.room
  local logic = room.logic

  if recoverData.card then
    local cardEffectData = logic:getCurrentEvent():findParent(GameEvent.CardEffect)
    if cardEffectData then
      local cardEffectEvent = cardEffectData.data
      recoverData.num = recoverData.num + (cardEffectEvent.additionalRecover or 0)
    end
  end

  local who = recoverData.who

  logic:trigger(fk.PreHpRecover, who, recoverData)
  recoverData.num = math.min(recoverData.num, who.maxHp - who.hp)
  if recoverData.num < 1 then
    recoverData.prevented = true
  end
  if recoverData.prevented then
    logic:breakEvent(false)
  end

  if not room:changeHp(who, recoverData.num, "recover", recoverData.skillName) then
    logic:breakEvent(false)
  end

  logic:trigger(fk.HpRecover, who, recoverData)
  return true
end

--- 根据回复数据回复体力。
---@param recoverDataSpec RecoverDataSpec
---@return boolean @ 是否成功回复体力
function HpEventWrappers:recover(recoverDataSpec)
  local recoverData = RecoverData:new(recoverDataSpec)
  return exec(Recover, recoverData)
end

---@class GameEvent.ChangeMaxHp : GameEvent
---@field public data MaxHpChangedData
local ChangeMaxHp = GameEvent:subclass("GameEvent.ChangeMaxHp")

function ChangeMaxHp:__tostring()
  local data = self.data
  return string.format("<ChangeMaxHp %d : %s #%d>",
    data.num, data.who, self.id)
end

function ChangeMaxHp:main()
  local data = self.data
  local room = self.room

  room.logic:trigger(fk.BeforeMaxHpChanged, data.who, data)
  if data.num == 0 then
    data.prevented = true
  end
  if data.prevented then
    room.logic:breakEvent(false)
  end

  local player = data.who
  local num = data.num

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
    room:killPlayer({ who = player })
    return false
  end

  local diff = player.hp - player.maxHp
  if diff > 0 then
    if not room:changeHp(player, -diff) then
      player.hp = player.hp - diff

      room:sendLog{
        type = "#ShowHPAndMaxHP",
        from = player.id,
        arg = player.hp,
        arg2 = player.maxHp,
      }
    end
  else
    room:sendLog{
      type = "#ShowHPAndMaxHP",
      from = player.id,
      arg = player.hp,
      arg2 = player.maxHp,
    }
  end

  room.logic:trigger(fk.MaxHpChanged, player, data)
  return true
end

--- 改变一名玩家的体力上限。
---@param player ServerPlayer @ 玩家
---@param num integer @ 变化量
---@return boolean
function HpEventWrappers:changeMaxHp(player, num)
  local data = MaxHpChangedData:new{
    who = player,
    num = num,
  }
  return exec(ChangeMaxHp, data)
end

return { ChangeHp, Damage, LoseHp, Recover, ChangeMaxHp, HpEventWrappers }
