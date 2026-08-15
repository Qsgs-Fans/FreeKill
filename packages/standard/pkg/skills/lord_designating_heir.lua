
local designating = fk.CreateSkill {
  name = "lord_designating_heir&",
  mode_skill = true,
}

Fk:loadTranslationTable{
  ["lord_designating_heir&"] = "立储",
  [":lord_designating_heir&"] = "第一轮限一次，你可以将一名其他角色立为储君：" ..
      "主公死亡时，若储君为忠臣，获得主公区域内至多两张牌，加1点体力上限，回复1点体力，变为主公；" ..
      "忠臣储君死亡时，主公失去1点体力；储君杀死主公弃置所有牌。（所有回合的空闲时间点发动）" ..
      "<br/><font color='gray'><small>操作提示：需预亮以发动；预亮后至下个空闲时发动。</small></font>",

  ["#lord_designating_heir&"] = "<font color='goldenrod'>立储</font>：你可以将一名其他角色立为储君",
  ["@@heir_of_throne-noclear"] = "<font color='goldenrod'>储君</font>",
  ["#lord_designating_heir&-xingshang"] = "立储：获得%src区域内至多两张牌",
  ["heir_usurpation"] = "储君夺位",
  ["heir_succession"] = "储君继位",
}

---@type TrigSkelSpec<TurnFunc|PhaseFunc>
local spec = {
  can_trigger = function (self, event, target, player, data)
    return player:hasSkill(designating.name) and player.role == "lord" and
        player.room:getBanner("RoundCount") == 1 and not player.room:getBanner("heir_designated")
  end,
  on_cost = function (self, event, target, player, data)
    local room = player.room
    local tos = room:askToChoosePlayers(player, {
      targets = room:getOtherPlayers(player, false),
      min_num = 1,
      max_num = 1,
      prompt = "#lord_designating_heir&",
      skill_name = designating.name,
      cancelable = true,
    })
    if #tos > 0 then
      event:setCostData(self, { tos = tos })
      return true
    end
  end,
  on_use = function (self, event, target, player, data)
    local room = player.room
    room:setBanner("heir_designated", true)
    local to = event:getCostData(self).tos[1]
    room:setPlayerMark(to, "@@heir_of_throne-noclear", player)
    player:loseFakeSkill(Fk.skills[designating.name])
  end,
}

designating:addEffect(fk.TurnEnd, spec)
designating:addEffect(fk.EventPhaseEnd, spec)
designating:addEffect(fk.BeforePlayCard, spec)

designating:addEffect(fk.RoundStart, {
  can_refresh = function (self, event, target, player, data)
    return player.room:getBanner("RoundCount") > 1 and player:hasSkill("-lord_designating_heir&", true)
  end,
  on_refresh = function (self, event, target, player, data)
    player.room:handleAddLoseSkills(player, "-lord_designating_heir&", nil, false, true)
  end,
})

designating:addEffect(fk.BeforeGameOverJudge, {
  priority = 0,
  mute = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target.role == "lord" and player:getMark("@@heir_of_throne-noclear") == target
      and player.role == "loyalist" and player:isAlive()
  end,
  on_cost = Util.TrueFunc,
  on_use = function (self, event, target, player, data)
    local room = player.room
    local bigSkilAnimate = function (name)
      room:doAnimate("InvokeUltSkill", {
        name = name,
        player = player.id,
        deputy = false,
      })
      room:delay(2000)
    end
    if data.killer == player then
      bigSkilAnimate("heir_usurpation") -- 储君夺位
      player:throwAllCards("he", designating.name)
    else
      bigSkilAnimate("heir_succession") -- 储君继位
    end
    if not target:isAllNude() then
      local cards = room:askToChooseCards(player, {
        target = target,
        min = 1,
        max = 2,
        flag = "hej",
        skill_name = designating.name,
        prompt = "#lord_designating_heir&-xingshang:" .. target.id,
      })
      room:obtainCard(player, cards, false, fk.ReasonPrey, player, designating.name)
    end
    if player.dead then return end
    room:changeMaxHp(player, 1)
    if player.dead then return end
    room:recover{ who = player, num = 1, skillName = designating.name }
    if player.dead then return end
    room:setPlayerProperty(player, "role", "lord")
    room:setPlayerProperty(player, "role_shown", true)
  end,
})

designating:addEffect(fk.Deathed, {
  priority = 0,
  anim_type = "negative",
  can_trigger = function (self, event, target, player, data)
    return target:getMark("@@heir_of_throne-noclear") == player and target.role == "loyalist"
  end,
  on_cost = Util.TrueFunc,
  on_use = function (self, event, target, player, data)
    player.room:loseHp(player, 1, designating.name)
  end
})

designating:addEffect(fk.AfterPropertyChange, {
  can_refresh = function (self, event, target, player, data)
    return target == player and table.contains(data.results.roleChange or {}, "lord")
  end,
  on_refresh = function (self, event, target, player, data)
    if player.role == "lord" then
      player:addFakeSkill(designating.name)
    else
      player:loseFakeSkill(designating.name)
    end
  end
})

return designating
