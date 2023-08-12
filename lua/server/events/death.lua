-- SPDX-License-Identifier: GPL-3.0-or-later

GameEvent.functions[GameEvent.Dying] = function(self)
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
      if dyingPlayer.hp > 0 or dyingPlayer.dead or logic:trigger(fk.AskForPeaches, p, dyingStruct) then
        break
      end
    end
    logic:trigger(fk.AskForPeachesDone, dyingPlayer, dyingStruct)
  end
end

GameEvent.exit_funcs[GameEvent.Dying] = function(self)
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

GameEvent.prepare_funcs[GameEvent.Death] = function(self)
  local deathStruct = table.unpack(self.data)
  local room = self.room
  local victim = room:getPlayerById(deathStruct.who)
  if victim.dead then
    return true
  end
end

GameEvent.functions[GameEvent.Death] = function(self)
  local deathStruct = table.unpack(self.data)
  local room = self.room
  local victim = room:getPlayerById(deathStruct.who)
  victim.dead = true
  victim._splayer:setDied(true)
  table.removeOne(room.alive_players, victim)

  local logic = room.logic
  logic:trigger(fk.BeforeGameOverJudge, victim, deathStruct)

  local killer = deathStruct.damage and deathStruct.damage.from or nil
  if killer then
    room:sendLog{
      type = "#KillPlayer",
      to = {killer.id},
      from = victim.id,
      arg = victim.role,
    }
  else
    room:sendLog{
      type = "#KillPlayerWithNoKiller",
      from = victim.id,
      arg = victim.role,
    }
  end
  room:sendLogEvent("Death", {to = victim.id})

  room:broadcastProperty(victim, "role")
  room:broadcastProperty(victim, "dead")

  victim.drank = 0
  room:broadcastProperty(victim, "drank")

  logic:trigger(fk.GameOverJudge, victim, deathStruct)
  logic:trigger(fk.Death, victim, deathStruct)
  logic:trigger(fk.BuryVictim, victim, deathStruct)

  logic:trigger(fk.Deathed, victim, deathStruct)
end
