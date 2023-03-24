GameEvent.functions[GameEvent.Dying] = function(self)
  local dyingStruct = table.unpack(self.data)
  local self = self.room
  local dyingPlayer = self:getPlayerById(dyingStruct.who)
  dyingPlayer.dying = true
  self:broadcastProperty(dyingPlayer, "dying")
  self:sendLog{
    type = "#EnterDying",
    from = dyingPlayer.id,
  }
  self.logic:trigger(fk.EnterDying, dyingPlayer, dyingStruct)

  if dyingPlayer.hp < 1 then
    -- self.logic:trigger(fk.Dying, dyingPlayer, dyingStruct)
    local savers = self:getAlivePlayers()
    for _, p in ipairs(savers) do
      if dyingPlayer.hp > 0 or dyingPlayer.dead or self.logic:trigger(fk.AskForPeaches, p, dyingStruct) then
        break
      end
    end
    self.logic:trigger(fk.AskForPeachesDone, dyingPlayer, dyingStruct)
  end

  if not dyingPlayer.dead and dyingPlayer.dying then
    dyingPlayer.dying = false
    self:broadcastProperty(dyingPlayer, "dying")
  end
  self.logic:trigger(fk.AfterDying, dyingPlayer, dyingStruct)
end

GameEvent.functions[GameEvent.Death] = function(self)
  local deathStruct = table.unpack(self.data)
  local self = self.room
  local victim = self:getPlayerById(deathStruct.who)
  victim.dead = true
  table.removeOne(self.alive_players, victim)

  local logic = self.logic
  logic:trigger(fk.BeforeGameOverJudge, victim, deathStruct)

  local killer = deathStruct.damage and deathStruct.damage.from or nil
  if killer then
    self:sendLog{
      type = "#KillPlayer",
      to = {killer.id},
      from = victim.id,
      arg = victim.role,
    }
  else
    self:sendLog{
      type = "#KillPlayerWithNoKiller",
      from = victim.id,
      arg = victim.role,
    }
  end
  self:sendLogEvent("Death", {to = victim.id})

  self:broadcastProperty(victim, "role")
  self:broadcastProperty(victim, "dead")

  victim.drank = 0
  self:broadcastProperty(victim, "drank")

  logic:trigger(fk.GameOverJudge, victim, deathStruct)
  logic:trigger(fk.Death, victim, deathStruct)
  logic:trigger(fk.BuryVictim, victim, deathStruct)
end
