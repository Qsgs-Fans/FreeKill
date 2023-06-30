-- SPDX-License-Identifier: GPL-3.0-or-later

---@param victim ServerPlayer
local function getWinner(victim)
  local room = victim.room
  local winner = ""
  local alive = room.alive_players

  if victim.role == "lord" then
    if #alive == 1 and alive[1].role == "renegade" then
      winner = "renegade"
    else
      winner = "rebel"
    end
  elseif victim.role ~= "loyalist" then
    local lord_win = true
    for _, p in ipairs(alive) do
      if p.role == "rebel" or p.role == "renegade" then
        lord_win = false
        break
      end
    end
    if lord_win then
      winner = "lord+loyalist"
    end
  end

  return winner
end

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
      while dyingPlayer.hp < 1 do
        local pattern = "peach"
        local prompt = "#AskForPeaches:" .. dyingPlayer.id .. "::" .. tostring(1 - dyingPlayer.hp)
        if player == dyingPlayer then
          pattern = pattern .. ",analeptic"
          prompt = "#AskForPeachesSelf:::" .. tostring(1 - dyingPlayer.hp)
        end

        local cardNames = pattern:split(",")
        for _, cardName in ipairs(cardNames) do
          local cardCloned = Fk:cloneCard(cardName)
          if player:prohibitUse(cardCloned) or player:isProhibited(dyingPlayer, cardCloned) then
            return
          end
        end

        local peach_use = room:askForUseCard(player, "peach", pattern, prompt)
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
      local winner = getWinner(player)
      if winner ~= "" then
        room:gameOver(winner)
        return true
      end
    end,
    [fk.BuryVictim] = function()
      player:bury()
      if room.tag["SkipNormalDeathProcess"] then
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
