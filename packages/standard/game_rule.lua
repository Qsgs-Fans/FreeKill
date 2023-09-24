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
      while dyingPlayer.hp < 1 do
        local cardNames = {"peach"}
        local prompt = "#AskForPeaches:" .. dyingPlayer.id .. "::" .. 1 - dyingPlayer.hp
        if player == dyingPlayer then
          table.insert(cardNames, "analeptic")
          prompt = "#AskForPeachesSelf:::" .. 1 - dyingPlayer.hp
        end

        cardNames = table.filter(cardNames, function (cardName)
          local cardCloned = Fk:cloneCard(cardName)
          return not (player:prohibitUse(cardCloned) or player:isProhibited(dyingPlayer, cardCloned))
        end)
        if #cardNames == 0 then return end

        room:notifyMoveFocus(player, "peach")
        local useData = {
          user = player,
          cardName = "peach",
          pattern = table.concat(cardNames, ","),
          extraData = Util.DummyTable
        }
        local use = nil
        room.logic:trigger(fk.AskForCardUse, player, useData)
        if type(useData.result) == "table" then
          useData = useData.result
          useData.tos = { { data.who } }
          if useData.card.trueName == "analeptic" then
            useData.extra_data = useData.extra_data or {}
            useData.extra_data.analepticRecover = true
          end
          room:useCard(useData)
          if useData.nullified then
            use = false
          elseif useData.breakEvent ~= true then
            use = useData
          end
        end
        if use == nil then
          useData = { "peach", table.concat(cardNames, ","), prompt, true, Util.DummyTable }
          Fk.currentResponsePattern = table.concat(cardNames, ",")
          local result = room:doRequest(player, "AskForUseCard", json.encode(useData))
          Fk.currentResponsePattern = nil
          if result ~= "" then
            result = room:handleUseCardReply(player, result)
            result.tos = { { data.who } }
            if result.card.trueName == "analeptic" then
              result.extra_data = result.extra_data or {}
              result.extra_data.analepticRecover = true
            end
            room:useCard(result)
          else
            return
          end
        end
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
