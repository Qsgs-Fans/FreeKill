-- SPDX-License-Identifier: GPL-3.0-or-later

---@class DeathEventWrappers: Object
local DeathEventWrappers = {} -- mixin

---@return boolean
local function exec(tp, ...)
  local event = tp:create(...)
  local _, ret = event:exec()
  return ret
end

---@class GameEvent.Dying : GameEvent
local Dying = GameEvent:subclass("GameEvent.Dying")
function Dying:main()
  local dyingStruct = table.unpack(self.data)
  local room = self.room
  local logic = room.logic
  local dyingPlayer = room:getPlayerById(dyingStruct.who)
  dyingPlayer.dying = true
  room:broadcastProperty(dyingPlayer, "dying")
  room:sendLog{
    type = "#EnterDying",
    from = dyingPlayer.id,
  }
  logic:trigger(fk.EnterDying, dyingPlayer, dyingStruct)

  if dyingPlayer.hp < 1 then
    -- room.logic:trigger(fk.Dying, dyingPlayer, dyingStruct)
    local savers = room:getAlivePlayers()
    for _, p in ipairs(savers) do
      if not p.dead then
        if dyingPlayer.hp > 0 or dyingPlayer.dead or logic:trigger(fk.AskForPeaches, p, dyingStruct) then
          break
        end
      end
    end
    logic:trigger(fk.AskForPeachesDone, dyingPlayer, dyingStruct)
  end
end

function Dying:exit()
  local room = self.room
  local logic = room.logic
  local dyingStruct = self.data[1]

  local dyingPlayer = room:getPlayerById(dyingStruct.who)

  if dyingPlayer.dying then
    dyingPlayer.dying = false
    room:broadcastProperty(dyingPlayer, "dying")
  end
  logic:trigger(fk.AfterDying, dyingPlayer, dyingStruct, self.interrupted)
end

--- 根据濒死数据让人进入濒死。
---@param dyingStruct DyingStruct
function DeathEventWrappers:enterDying(dyingStruct)
  return exec(Dying, dyingStruct)
end

---@class GameEvent.Death : GameEvent
local Death = GameEvent:subclass("GameEvent.Death")
function Death:prepare()
  local deathStruct = table.unpack(self.data)
  local room = self.room
  local victim = room:getPlayerById(deathStruct.who)
  if victim.dead then
    return true
  end
end

function Death:main()
  local deathStruct = table.unpack(self.data)
  local room = self.room
  local victim = room:getPlayerById(deathStruct.who)
  victim.dead = true

  if victim.rest <= 0 then
    victim._splayer:setDied(true)
  end

  table.removeOne(room.alive_players, victim)

  local logic = room.logic
  logic:trigger(fk.BeforeGameOverJudge, victim, deathStruct)

  local killer = deathStruct.damage and deathStruct.damage.from or nil
  if killer then
    room:sendLog{
      type = "#KillPlayer",
      to = {killer.id},
      from = victim.id,
      arg = (victim.rest > 0 and 'unknown' or victim.role),
    }
  else
    room:sendLog{
      type = "#KillPlayerWithNoKiller",
      from = victim.id,
      arg = (victim.rest > 0 and 'unknown' or victim.role),
    }
  end
  room:sendLogEvent("Death", {to = victim.id})

  if victim.rest == 0 then
    room:broadcastProperty(victim, "role")
  end
  room:broadcastProperty(victim, "dead")

  victim.drank = 0
  room:broadcastProperty(victim, "drank")
  victim.shield = 0
  room:broadcastProperty(victim, "shield")

  logic:trigger(fk.GameOverJudge, victim, deathStruct)
  logic:trigger(fk.Death, victim, deathStruct)
  logic:trigger(fk.BuryVictim, victim, deathStruct)

  logic:trigger(fk.Deathed, victim, deathStruct)
end

--- 根据死亡数据杀死角色。
---@param deathStruct DeathStruct
function DeathEventWrappers:killPlayer(deathStruct)
  return exec(Death, deathStruct)
end

---@class GameEvent.Revive : GameEvent
local Revive = GameEvent:subclass("GameEvent.Revive")
function Revive:main()
  local room = self.room
  local player, sendLog, reason = table.unpack(self.data)

  if not player.dead then return end
  room:setPlayerProperty(player, "dead", false)
  player._splayer:setDied(false)
  room:setPlayerProperty(player, "dying", false)
  room:setPlayerProperty(player, "hp", player.maxHp)
  table.insertIfNeed(room.alive_players, player)

  sendLog = (sendLog == nil) and true or sendLog
  if sendLog then
    room:sendLog { type = "#Revive", from = player.id }
  end

  reason = reason or ""
  room.logic:trigger(fk.AfterPlayerRevived, player, { reason = reason })
end

---@param player ServerPlayer
---@param sendLog? bool
function DeathEventWrappers:revivePlayer(player, sendLog, reason)
  return exec(Revive, player, sendLog, reason)
end

return { Dying, Death, Revive, DeathEventWrappers }
