
local loyalty = fk.CreateSkill {
  name = "renegade_loyalty&",
  mode_skill = true,
}

Fk:loadTranslationTable{
  ["renegade_loyalty&"] = "侍奉明主",
  [":renegade_loyalty&"] = "场上人数＞4且有主忠死亡时，你可以变为忠臣。（出牌阶段或每个回合结束时结算）" ..
      "<br/><font color='gray'><small>操作提示：需预亮以发动；出牌阶段空闲时从不预亮点为预亮需等待至下个空闲时发动</small></font>",

  ["#renegade_loyalty&"] = "<font color='darkgoldenrod'>侍奉明主</font>：是否变为忠臣？",
}

---@type TrigSkelSpec<TurnFunc|PhaseFunc>
local spec = {
  anim_type = "big",
  can_trigger = function (self, event, target, player, data)
    if not player:hasSkill(loyalty.name) or player.role ~= "renegade" or not (event == fk.TurnEnd or player == target) then return end
    local room = player.room
    return #room.alive_players > 4 and table.find(room.players, function(p) return p.dead and (p.role == "loyalist" or p.role == "lord") end)
  end,
  on_cost = function (self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = loyalty.name, prompt = "#renegade_loyalty&",
    })
  end,
  on_use = function (self, event, target, player, data)
    local room = player.room
    player:loseFakeSkill("renegade_wild&")
    room:changeRole(player, "loyalist", true)
    room:setPlayerProperty(player, "role_shown", true)
  end,
}

loyalty:addEffect(fk.TurnEnd, spec)

loyalty:addEffect(fk.BeforePlayCard, spec)

loyalty:addEffect(fk.AfterPropertyChange, {
  can_refresh = function (self, event, target, player, data)
    return target == player and table.contains(data.results.roleChange or {}, "renegade")
  end,
  on_refresh = function (self, event, target, player, data)
    if player.role == "renegade" then
      player:addFakeSkill("renegade_loyalty&")
    else
      player:loseFakeSkill("renegade_loyalty&")
    end
  end
})

return loyalty
