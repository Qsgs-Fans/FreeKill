
local tuxi = fk.CreateSkill {
  name = "tuxi",
}

tuxi:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(tuxi.name) and player.phase == Player.Draw and not data.phase_end and
      table.find(player.room:getOtherPlayers(player, false), function(p)
        return not p:isKongcheng()
      end)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = table.filter(room:getOtherPlayers(player, false), function(p)
      return not p:isKongcheng()
    end)
    local tos = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = 2,
      prompt = "#tuxi-ask",
      skill_name = tuxi.name,
    })
    if #tos > 0 then
      room:sortByAction(tos)
      event:setCostData(self, { tos = tos })
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data.phase_end = true
    for _, p in ipairs(event:getCostData(self).tos) do
      if player.dead then break end
      if not p.dead and not p:isKongcheng() then
        local c = room:askToChooseCard(player, {
          target = p,
          flag = "h",
          skill_name = tuxi.name,
        })
        room:obtainCard(player, c, false, fk.ReasonPrey, player, tuxi.name)
      end
    end
  end,
})

tuxi:addAI(Fk.Ltk.AI.newChoosePlayersStrategy{
  choose_players = function(self, ai)
    return ai:askToChoosePlayers({
      targets = ai:getEnabledTargets(),
      min_num = 0,
      max_num = 2,
      skill_name = tuxi.name,
      benefit_func = function (logic, p)
        local ret, _ = ai:askToChooseCards({
          cards = p:getCardIds("h"),
          skill_name = tuxi.name,
          data = {
            toArea = Card.PlayerHand,
            target = ai.player,
            reason = fk.ReasonPrey,
            proposer = ai.player,
          }
        })
        logic:obtainCard(ai.player, ret, false, fk.ReasonPrey, ai.player, tuxi.name)
      end,
      basic_benefit = -ai:getBenefitOfEvents(function(logic)
        logic:drawCards(ai.player, 2, "phase_draw")
      end),
    })
  end,
})

return tuxi
