local wild = fk.CreateSkill {
  name = "renegade_wild&",
  mode_skill = true,
}

Fk:loadTranslationTable{
  ["renegade_wild&"] = "自立",
  [":renegade_wild&"] = "内奸可以成为野心家：获得野心家标记（出牌阶段，弃置以摸两张牌或回复1点体力）" ..
      "和〖飞扬〗〖跋扈〗，杀死角色摸三张牌。（出牌阶段或每个回合结束时结算）" ..
      "<br/><font color='gray'><small>操作提示：需预亮以发动；出牌阶段空闲时从不预亮点为预亮需等待至下个空闲时发动</small></font>",

  ["#renegade_wild&"] = "<font color='mediumorchid'>自立</font>：是否变为野心家？",
}

---@type TrigSkelSpec<TurnFunc|PhaseFunc>
local spec = {
  anim_type = "big",
  can_trigger = function (self, event, target, player, data)
    return player:hasSkill(wild.name) and player.role == "renegade" and (event == fk.TurnEnd or player == target)
  end,
  on_cost = function (self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = wild.name, prompt = "#renegade_wild&",
    })
  end,
  on_use = function (self, event, target, player, data)
    local room = player.room
    room:addPlayerMark(player, "@!!m_role_wild", 1)
    room:changeRole(player, "wild", true)
    room:setPlayerProperty(player, "role_shown", true)
    room:handleAddLoseSkills(player, "m_feiyang|m_bahu|m_role_wild_draw&", nil, false, true)
  end,
}

wild:addEffect(fk.TurnEnd, spec)

wild:addEffect(fk.BeforePlayCard, spec)

wild:addEffect(fk.AfterPropertyChange, {
  can_refresh = function (self, event, target, player, data)
    return target == player and table.contains(data.results.roleChange or {}, "renegade")
  end,
  on_refresh = function (self, event, target, player, data)
    if player.role == "renegade" then
      player:addFakeSkill("renegade_wild&")
    else
      player:loseFakeSkill("renegade_wild&")
    end
  end
})

return wild
