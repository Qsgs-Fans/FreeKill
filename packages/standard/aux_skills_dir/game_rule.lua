local gameRule = fk.CreateSkill{
  name = "game_rule",
}

local can_trigger = function(self, event, target, player, data)
  return (target == player) or (target == nil)
end

gameRule:addEffect(fk.GamePrepared, {
  priority = 0,
  can_trigger = can_trigger,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    if room:getTag("SkipGameRule") then
      room:setTag("SkipGameRule", false)
      return false
    end

    room:setTag("FirstRound", true)
    room:setTag("RoundCount", 0)
  end,
})

gameRule:addEffect(fk.AskForPeaches, {
  priority = 0,
  can_trigger = can_trigger,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    if room:getTag("SkipGameRule") then
      room:setTag("SkipGameRule", false)
      return false
    end

    local dyingPlayer = data.who
    while not (player.dead or dyingPlayer.dead) and dyingPlayer.hp < 1 do
      local cardNames = {"peach"}
      local prompt = "#AskForPeaches:" .. dyingPlayer.id .. "::" .. tostring(1 - dyingPlayer.hp)
      if player == dyingPlayer then
        table.insert(cardNames, "analeptic")
        prompt = "#AskForPeachesSelf:::" .. tostring(1 - dyingPlayer.hp)
      end

      cardNames = table.filter(cardNames, function (cardName)
        local cardCloned = Fk:cloneCard(cardName)
        cardCloned:setVSPattern(nil, nil, ".")
        return not (player:prohibitUse(cardCloned) or player:isProhibited(dyingPlayer, cardCloned))
      end)
      if #cardNames == 0 then return end

      local params = { ---@type AskToUseCardParams
        skill_name = "peach",
        pattern = table.concat(cardNames, ","),
        prompt = prompt,
        cancelable = true,
        extra_data = {
          analepticRecover = true,
          must_targets = { dyingPlayer.id },
          fix_targets = { dyingPlayer.id }
        }
      }
      local peach_use = room:askToUseCard(player, params)
      if not peach_use then break end
      peach_use.tos = { dyingPlayer }
      if peach_use.card.trueName == "analeptic" then
        peach_use.extra_data = peach_use.extra_data or {}
        peach_use.extra_data.analepticRecover = true
      end
      room:useCard(peach_use)
    end
  end,
})

gameRule:addEffect(fk.AskForPeachesDone, {
  priority = 0,
  can_trigger = can_trigger,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    if room:getTag("SkipGameRule") then
      room:setTag("SkipGameRule", false)
      return false
    end

    if player.hp < 1 and not data.ignoreDeath then
      ---@type DeathDataSpec
      local deathData = {
        who = player,
        killer = data.damage and data.damage.from,
        damage = data.damage,
      }
      room:killPlayer(deathData)
    end
  end,
})

gameRule:addEffect(fk.GameOverJudge, {
  priority = 0,
  can_trigger = can_trigger,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    if room:getTag("SkipGameRule") then
      room:setTag("SkipGameRule", false)
      return false
    end

    local winner = Fk.game_modes[room:getSettings('gameMode')]:getWinner(player)
    if winner ~= "" then
      room:gameOver(winner)
      return true
    end
  end,
})

gameRule:addEffect(fk.BuryVictim, {
  priority = 0,
  can_trigger = can_trigger,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    if room:getTag("SkipGameRule") then
      room:setTag("SkipGameRule", false)
      return false
    end

    player:bury()
    room:doBroadcastNotify("UpdateMarkArea", {
      id = player.id,
      change = {
        visible = false,
      },
    })
    if room.tag["SkipNormalDeathProcess"] or player.rest > 0 or (data.extra_data and data.extra_data.skip_reward_punish) then
      return false
    end
    Fk.game_modes[room:getSettings('gameMode')]:deathRewardAndPunish(player, data.killer)
  end,
})

return gameRule
