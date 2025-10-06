local tieqi = fk.CreateSkill {
  name = "tieqi",
}

tieqi:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(tieqi.name) and data.card.trueName == "slash"
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local judge = {
      who = player,
      reason = tieqi.name,
      pattern = ".|.|red",
    }
    room:judge(judge)
    if judge:matchPattern() then
      data.disresponsive = true
    end
  end,
})

tieqi:addAI({
  think_skill_invoke = function(self, ai, skill_name, prompt)
    ---@type UseCardData
    local dmg = ai.room.logic:getCurrentEvent().data
    local targets = dmg.tos
    if not targets then return false end

    --- TODO 能跑，但是返回是0
    --- TODO 需要注意targets的问题 例如：方天多个目标
    -- local use_val = ai:getBenefitOfEvents(function(logic)
    --   logic:useCard{
    --     from = ai.player.id,
    --     to = targets[1],
    --     card = dmg.card
    --   }
    -- end)

    -- if use_val >= 0 then
    --   return true
    -- end

    -- return false

    return ai:isEnemy(targets[1])
  end,
})

return tieqi
