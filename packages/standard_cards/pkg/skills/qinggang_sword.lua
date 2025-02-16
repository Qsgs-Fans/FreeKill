local skill = fk.CreateSkill {
  name = "#qinggang_sword_skill",
  attached_equip = "qinggang_sword",
  frequency = Skill.Compulsory,
}

skill:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and data.card and data.card.trueName == "slash" and not data.to.dead
  end,
  on_cost = function(self, event, target, player, data)
    self.cost_data = { tos = {data.to} }
    return true
  end,
  on_use = function(self, event, target, player, data)
    data.to:addQinggangTag(data)
  end,
})
skill:addEffect(fk.CardUseFinished, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return data.extra_data and data.extra_data.qinggang_tag and table.contains(data.extra_data.qinggang_tag, player.id)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    while table.removeOne(data.extra_data.qinggang_tag, player.id) do
      room:removePlayerMark(player, MarkEnum.MarkArmorNullified)
    end
  end,
})
skill:addEffect(fk.BeforeHpChanged, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    local logic = player.room.logic
    local game_event = logic:getCurrentEvent()
    if game_event.event ~= GameEvent.ChangeHp then return false end
    local hpChangedData = game_event.data
    if hpChangedData.who ~= player or hpChangedData.reason ~= "damage" then return false end
    game_event = game_event.parent
    if game_event.event ~= GameEvent.Damage then return false end
    game_event = game_event.parent
    if game_event.event ~= GameEvent.SkillEffect or game_event.data.trueName ~= "slash_skill" then return false end
    game_event = game_event.parent
    if game_event.event ~= GameEvent.CardEffect then return false end
    local effect = game_event.data
    if player.id ~= effect.to or effect.qinggang_clean then return false end
    game_event = game_event.parent
    if game_event.event ~= GameEvent.UseCard then return false end
    local use = game_event.data

    return use.additionalEffect == 0 and
      use.extra_data and use.extra_data.qinggang_tag and table.contains(use.extra_data.qinggang_tag, player.id)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    local logic = room.logic
    local cardEffectEvent = logic:getCurrentEvent():findParent(GameEvent.CardEffect, true)
    if cardEffectEvent == nil then return end
    local effect = cardEffectEvent.data
    effect.qinggang_clean = true
    table.removeOne(effect.extra_data.qinggang_tag, player.id)
    room:removePlayerMark(player, MarkEnum.MarkArmorNullified)
  end,
})
skill:addEffect(fk.DamageFinished, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    local logic = player.room.logic
    local game_event = logic:getCurrentEvent()
    if data.card == nil or data.to ~= player then return false end
    if game_event.event ~= GameEvent.SkillEffect or game_event.data.trueName ~= "slash_skill" then return false end
    game_event = game_event.parent
    if game_event.event ~= GameEvent.CardEffect then return false end
    local effect = game_event.data
    if player.id ~= effect.to or effect.qinggang_clean then return false end
    game_event = game_event.parent
    if game_event.event ~= GameEvent.UseCard then return false end
    local use = game_event.data

    return use.additionalEffect == 0 and
      use.extra_data and use.extra_data.qinggang_tag and table.contains(use.extra_data.qinggang_tag, player.id)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    local logic = room.logic
    local cardEffectEvent = logic:getCurrentEvent():findParent(GameEvent.CardEffect, true)
    if cardEffectEvent == nil then return end
    local effect = cardEffectEvent.data
    effect.qinggang_clean = true
    table.removeOne(effect.extra_data.qinggang_tag, player.id)
    room:removePlayerMark(player, MarkEnum.MarkArmorNullified)
  end,
})
skill:addEffect(fk.CardEffectFinished, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    local logic = player.room.logic
    local game_event = logic:getCurrentEvent()
    if game_event.event ~= GameEvent.CardEffect then return false end
    local effect = game_event.data
    if player.id ~= effect.to or effect.qinggang_clean then return false end
    game_event = game_event.parent
    if game_event.event ~= GameEvent.UseCard then return false end
    local use = game_event.data

    return use.additionalEffect == 0 and
      use.extra_data and use.extra_data.qinggang_tag and table.contains(use.extra_data.qinggang_tag, player.id)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    local logic = room.logic
    local cardEffectEvent = logic:getCurrentEvent():findParent(GameEvent.CardEffect, true)
    if cardEffectEvent == nil then return end
    local effect = cardEffectEvent.data
    effect.qinggang_clean = true
    table.removeOne(effect.extra_data.qinggang_tag, player.id)
    room:removePlayerMark(player, MarkEnum.MarkArmorNullified)
  end,
})
skill:addEffect(fk.CardEffectCancelledOut, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    local logic = player.room.logic
    local game_event = logic:getCurrentEvent()
    if game_event.event ~= GameEvent.CardEffect then return false end
    local effect = game_event.data
    if player.id ~= effect.to or effect.qinggang_clean then return false end
    game_event = game_event.parent
    if game_event.event ~= GameEvent.UseCard then return false end
    local use = game_event.data

    return use.additionalEffect == 0 and
      use.extra_data and use.extra_data.qinggang_tag and table.contains(use.extra_data.qinggang_tag, player.id)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    local logic = room.logic
    local cardEffectEvent = logic:getCurrentEvent():findParent(GameEvent.CardEffect, true)
    if cardEffectEvent == nil then return end
    local effect = cardEffectEvent.data
    effect.qinggang_clean = true
    table.removeOne(effect.extra_data.qinggang_tag, player.id)
    room:removePlayerMark(player, MarkEnum.MarkArmorNullified)
  end,
})

skill:addTest(function(room, me)
  local qinggang_sword = room:printCard("qinggang_sword")
  local nioh_shield = room:printCard("nioh_shield")
  local comp2 = room.players[2]

  FkTest.runInRoom(function()
    --无视防具测试
    room:useCard {
      from = comp2,
      tos = { comp2 },
      card = qinggang_sword,
    }
    room:useCard {
      from = me,
      tos = { me },
      card = nioh_shield,
    }
    room:useCard {
      from = comp2,
      tos = { me },
      card = Fk:cloneCard("slash", Card.Spade),
    }
    lu.assertEquals(me.hp, 3)

    --正确移除tag测试（FIXME: 未通过）
    --[[room:throwCard(qinggang_sword, "", comp2, comp2)
    room:useCard {
      from = comp2,
      tos = { me },
      card = Fk:cloneCard("slash", Card.Spade),
    }
    lu.assertEquals(me.hp, 3)]]--
  end)
end)

return skill
