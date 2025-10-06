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
---@field data DyingData
local Dying = GameEvent:subclass("GameEvent.Dying")

function Dying:__tostring()
  local data = self.data
  return string.format("<Dying %s <= %s #%d>",
    data.who, data.killer, self.id)
end

function Dying:main()
  local dyingData = self.data
  local room = self.room
  local logic = room.logic
  local dyingPlayer = dyingData.who
  dyingPlayer.dying = true
  room:broadcastProperty(dyingPlayer, "dying")
  room:sendLog{
    type = "#EnterDying",
    from = dyingPlayer.id,
  }
  logic:trigger(fk.EnterDying, dyingPlayer, dyingData)

  if dyingPlayer.hp < 1 then
    -- room.logic:trigger(fk.Dying, dyingPlayer, dyingStruct)
    local savers = room:getAlivePlayers()
    for _, p in ipairs(savers) do
      if not p.dead then
        if dyingPlayer.hp > 0 or dyingPlayer.dead or logic:trigger(fk.AskForPeaches, p, dyingData) then
          break
        end
      end
    end
    logic:trigger(fk.AskForPeachesDone, dyingPlayer, dyingData)
  end
end

function Dying:exit()
  local room = self.room
  local logic = room.logic
  local dyingData = self.data

  local dyingPlayer = dyingData.who

  if dyingPlayer.dying then
    dyingPlayer.dying = false
    room:broadcastProperty(dyingPlayer, "dying")
  end
  logic:trigger(fk.AfterDying, dyingPlayer, dyingData, self.interrupted)
end

--- 根据濒死数据让人进入濒死。
---@param dyingDataSpec DyingDataSpec
function DeathEventWrappers:enterDying(dyingDataSpec)
  local dyingData = DyingData:new(dyingDataSpec)
  return exec(Dying, dyingData)
end

---@class GameEvent.Death : GameEvent
---@field data DeathData
local Death = GameEvent:subclass("GameEvent.Death")

function Death:__tostring()
  local data = self.data
  return string.format("<Death %s <= %s #%d>",
    data.who, data.killer, self.id)
end

function Death:prepare()
  local deathData = self.data
  local victim = deathData.who
  if victim.dead then
    return true
  end
end

function Death:main()
  local deathData = self.data
  local room = self.room
  local victim = deathData.who
  victim.dead = true

  if victim.rest <= 0 then
    victim._splayer:setDied(true)
  end

  table.removeOne(room.alive_players, victim)

  local logic = room.logic
  logic:trigger(fk.BeforeGameOverJudge, victim, deathData)

  local killer = deathData.killer
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
    room:setPlayerProperty(victim, "role_shown", true)
    -- room:broadcastProperty(victim, "role")
  end
  room:broadcastProperty(victim, "dead")

  victim.drank = 0
  room:broadcastProperty(victim, "drank")
  victim.shield = 0
  room:broadcastProperty(victim, "shield")
  room:updateAllLimitSkillUI(victim)

  logic:trigger(fk.GameOverJudge, victim, deathData)
  logic:trigger(fk.Death, victim, deathData)
  logic:trigger(fk.BuryVictim, victim, deathData)

  logic:trigger(fk.Deathed, victim, deathData)
end

--- 根据死亡数据杀死角色。
---@param deathDataSpec DeathDataSpec
function DeathEventWrappers:killPlayer(deathDataSpec)
  local deathData = DeathData:new(deathDataSpec)
  return exec(Death, deathData)
end

---@class GameEvent.Revive : GameEvent
---@field data ReviveData
local Revive = GameEvent:subclass("GameEvent.Revive")

function Revive:__tostring()
  local data = self.data
  return string.format("<Revive %s #%d>",
    data.who, self.id)
end

function Revive:main()
  local room = self.room
  local data = self.data

  if not data.who.dead then return end
  room:setPlayerProperty(data.who, "dead", false)
  data.who._splayer:setDied(false)
  room:setPlayerProperty(data.who, "dying", false)
  room:setPlayerProperty(data.who, "hp", data.who.maxHp)
  table.insertIfNeed(room.alive_players, data.who)
  room:updateAllLimitSkillUI(data.who)

  if data.send_log then
    room:sendLog { type = "#Revive", from = data.who.id }
  end

  room.logic:trigger(fk.AfterPlayerRevived, data.who, data)
end

--- 复活一个角色
---@param player ServerPlayer @ 要复活的角色
---@param sendLog? boolean? @ 是否播放战报
---@param reason? string? @ 复活原因
function DeathEventWrappers:revivePlayer(player, sendLog, reason)
  sendLog = (sendLog == nil) and true or sendLog
  reason = reason or ""
  local data = ReviveData:new{
    who = player,
    reason = reason,
    send_log = sendLog
  }
  return exec(Revive, data)
end

return { Dying, Death, Revive, DeathEventWrappers }
