-- SPDX-License-Identifier: GPL-3.0-or-later

---@param killer ServerPlayer
local function rewardAndPunish(killer, victim)
  if killer.dead then return end
  if victim.role == "rebel" then
    killer:drawCards(3, "kill")
  elseif victim.role == "loyalist" and killer.role == "lord" then
    killer:throwAllCards("he")
  end
end

GameRule = fk.CreateTriggerSkill{
  name = "game_rule",
  events = {
    fk.GamePrepared,
    fk.AskForPeaches, fk.AskForPeachesDone,
    fk.GameOverJudge, fk.BuryVictim,
  },
  priority = 0,

  can_trigger = function(self, event, target, player, data)
    return (target == player) or (target == nil)
  end,

  on_trigger = function(self, event, target, player, data)
    local room = player.room
    if room:getTag("SkipGameRule") then
      room:setTag("SkipGameRule", false)
      return false
    end

    if event == fk.GamePrepared then
      room:setTag("FirstRound", true)
      room:setTag("RoundCount", 0)
      return false
    end

    switch(event, {
    [fk.AskForPeaches] = function()
      local dyingPlayer = room:getPlayerById(data.who)
      while not (player.dead or dyingPlayer.dead) and dyingPlayer.hp < 1 do
        local cardNames = {"peach"}
        local prompt = "#AskForPeaches:" .. dyingPlayer.id .. "::" .. tostring(1 - dyingPlayer.hp)
        if player == dyingPlayer then
          table.insert(cardNames, "analeptic")
          prompt = "#AskForPeachesSelf:::" .. tostring(1 - dyingPlayer.hp)
        end

        cardNames = table.filter(cardNames, function (cardName)
          -- FIXME: 应该印一个“任何情况都适合”的牌，或者说根本不该有这个过滤
          local cardCloned = Fk:cloneCard(cardName)
          return not (player:prohibitUse(cardCloned) or player:isProhibited(dyingPlayer, cardCloned))
        end)
        if #cardNames == 0 then return end

        local peach_use = room:askForUseCard(
          player,
          "peach",
          table.concat(cardNames, ","),
          prompt,
          true,
          {analepticRecover = true, must_targets = { dyingPlayer.id }}
        )
        if not peach_use then break end
        peach_use.tos = { {dyingPlayer.id} }
        if peach_use.card.trueName == "analeptic" then
          peach_use.extra_data = peach_use.extra_data or {}
          peach_use.extra_data.analepticRecover = true
        end
        room:useCard(peach_use)
      end
    end,
    [fk.AskForPeachesDone] = function()
      if player.hp < 1 and not data.ignoreDeath then
        ---@type DeathStruct
        local deathData = {
          who = player.id,
          damage = data.damage,
        }
        room:killPlayer(deathData)
      end
    end,
    [fk.GameOverJudge] = function()
      local winner = Fk.game_modes[room.settings.gameMode]:getWinner(player)
      if winner ~= "" then
        room:gameOver(winner)
        return true
      end
    end,
    [fk.BuryVictim] = function()
      player:bury()
      if room.tag["SkipNormalDeathProcess"] or player.rest > 0 then
        return false
      end
      local damage = data.damage
      if damage and damage.from then
        local killer = damage.from
        rewardAndPunish(killer, player);
      end
    end,
    default = function()
      print("game_rule: Event=" .. event)
      room:askForSkillInvoke(player, "rule")
    end,
    })
    return false
  end,

}

local fastchat_m = fk.CreateActiveSkill{ name = "fastchat_m" }
local fastchat_f = fk.CreateActiveSkill{ name = "fastchat_f" }
Fk:addSkill(fastchat_m)
Fk:addSkill(fastchat_f)
