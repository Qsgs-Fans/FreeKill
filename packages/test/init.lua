-- SPDX-License-Identifier: GPL-3.0-or-later

local extension = Package("test_p_0")

local cheat = fk.CreateActiveSkill{
  name = "cheat",
  anim_type = "drawcard",
  can_use = function(self, player)
    return true
  end,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    local cardTypeName = room:askForChoice(from, { 'BasicCard', 'TrickCard', 'Equip' }, "cheat")
    local cardType = Card.TypeBasic
    if cardTypeName == 'TrickCard' then
      cardType = Card.TypeTrick
    elseif cardTypeName == 'Equip' then
      cardType = Card.TypeEquip
    end

    local allCardIds = Fk:getAllCardIds()
    local allCardMapper = {}
    local allCardNames = {}
    for _, id in ipairs(allCardIds) do
      local card = Fk:getCardById(id)
      if card.type == cardType then
        if allCardMapper[card.name] == nil then
          table.insert(allCardNames, card.name)
        end

        allCardMapper[card.name] = allCardMapper[card.name] or {}
        table.insert(allCardMapper[card.name], id)
      end
    end

    if #allCardNames == 0 then
      return
    end

    local cardName = room:askForChoice(from, allCardNames, "cheat", nil, nil, true)
    local toGain = nil
    if #allCardMapper[cardName] > 0 then
      toGain = allCardMapper[cardName][math.random(1, #allCardMapper[cardName])]
    end

    from:addToPile(self.name, toGain, true, self.name)
    room:obtainCard(effect.from, toGain, true, fk.ReasonPrey)
  end
}
local test_filter = fk.CreateFilterSkill{
  name = "test_filter",
  card_filter = function(self, card)
    return card.number > 11
  end,
  view_as = function(self, card)
    return Fk:cloneCard("crossbow", card.suit, card.number)
  end,
}
local control = fk.CreateActiveSkill{
  name = "control",
  anim_type = "control",
  can_use = function(self, player)
    return true
  end,
  card_filter = function(self, card)
    -- if self.interaction.data == "joy" then
      --local c = Fk:getCardById(card)
      --return Self:getPileNameOfId(card) == self.name and c.color == Card.Red
      return false
    -- end
  end,
  card_num = 0,
  target_filter = function(self, to_select)
    return to_select ~= Self.id
  end,
  min_target_num = 1,
  --interaction = function()return UI.Spin {
    --choices = Fk.package_names,
    --from=2,to=8,
    -- default = "guanyu",
  --}end,
  on_use = function(self, room, effect)
    --room:doSuperLightBox("packages/test/qml/Test.qml")
    local from = room:getPlayerById(effect.from)
    -- room:swapSeat(from, to)
    for _, pid in ipairs(effect.tos) do
      local to = room:getPlayerById(pid)
      if to:getMark("mouxushengcontrolled") == 0 then
        room:addPlayerMark(to, "mouxushengcontrolled")
        from:control(to)
      else
        room:setPlayerMark(to, "mouxushengcontrolled", 0)
        to:control(to)
      end
    end
    --local success, dat = room:askForUseViewAsSkill(from, "test_vs", nil, true)
    --if success then
      --local card = Fk.skills["test_vs"]:viewAs(dat.cards)
      --room:useCard{
        --from = from.id,
        --tos = table.map(dat.targets, function(e) return {e} end),
        --card = card,
      --}
    --end
    -- from:pindian({to})
    -- local result = room:askForCustomDialog(from, "simayi", "packages/test/qml/TestDialog.qml", "Hello, world. FROM LUA")
    -- print(result)

    -- room:fillAG(from, { 1, 43, 77 })
    -- local id = room:askForAG(from, { 1, 43, 77 })
    -- room:takeAG(from, id)
    -- room:delay(2000)
    -- room:closeAG(from)
    -- local cards = room:askForCardsChosen(from, from, 2, 3, "hej", "")
    -- from:addToPile(self.name, cards)
    -- from.kingdom = "wei"
    -- room:broadcastProperty(from, "kingdom")
    -- p(cards)
    -- room:useVirtualCard("slash", nil, from, room:getOtherPlayers(from), self.name, true)
  end,
}
local test_vs = fk.CreateViewAsSkill{
  name = "test_vs",
  pattern = "nullification",
  card_filter = function(self, to_select, selected)
    return #selected == 0
  end,
  interaction = function(self)
    return UI.ComboBox {
      choices = {
        "ex_nihilo",
        "duel",
        "snatch",
        "dismantlement",
        "savage_assault",
        "archery_attack",
        "lightning",
        "nullification",
      },
      detailed = true,
    }
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    if not self.interaction.data then return end
    local c = Fk:cloneCard(self.interaction.data)
    c.skillName = self.name
    c:addSubcard(cards[1])
    return c
  end,
}
local test_trig = fk.CreateTriggerSkill{
  name = "test_trig",
  events = {fk.EventPhaseEnd},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and player.phase == Player.Discard
  end,
  on_cost = function(self, event, target, player, data)
    local cards = player.room:askForDiscard(player, 1, 1, false, self.name, true, nil, "#test_trig-ask", true)
    if #cards > 0 then
      self.cost_data = cards
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    player.room:throwCard(self.cost_data, self.name, player, player)
  end,
}
local damage_maker = fk.CreateActiveSkill{
  name = "damage_maker",
  anim_type = "offensive",
  can_use = function(self, player)
    return true
  end,
  card_filter = function(self, card)
    return false
  end,
  card_num = 0,
  target_filter = function(self)
    return true
  end,
  target_num = 1,
  interaction = function()return UI.ComboBox {
    choices = {"normal_damage", "fire_damage", "thunder_damage", "ice_damage", "lose_hp", "heal_hp", "lose_max_hp", "heal_max_hp"}
  }end,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    local choice = self.interaction.data
    local choices = {}
    for i = 1, 99 do
      table.insert(choices, tostring(i))
    end
    local number = tonumber(room:askForChoice(from, choices, self.name, nil))
    if choice == "heal_hp" then
      room:recover{
        who = target,
        num = number,
        recoverBy = from,
        skillName = self.name
      }
    elseif choice == "heal_max_hp" then
      room:changeMaxHp(target, number)
    elseif choice == "lose_max_hp" then
      room:changeMaxHp(target, -number)
    elseif choice == "lose_hp" then
      room:loseHp(target, number, self.name)
    else
      choices = {"normal_damage", "fire_damage", "thunder_damage", "ice_damage"}
      room:damage({
        from = from,
        to = target,
        damage = number,
        damageType = table.indexOf(choices, choice),
        skillName = self.name
      })
    end
  end,
}
local change_hero = fk.CreateActiveSkill{
  name = "change_hero",
  can_use = function(self, player)
    return true
  end,
  card_filter = function(self, card)
    return false
  end,
  card_num = 0,
  target_filter = function(self, to_select, selected)
    return #selected < 1
  end,
  target_num = 1,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    local generals = table.map(Fk:getGeneralsRandomly(8, Fk:getAllGenerals()), function(p) return p.name end)
    local general = room:askForGeneral(from, generals, 1)
    if general == nil then
      general = table.random(generals)
    end
    room:changeHero(target, general, false, false, true)
  end,
}
local test_zhenggong = fk.CreateTriggerSkill{
  name = "test_zhenggong",
  events = {fk.RoundStart},
  frequency = Skill.Compulsory,
  anim_type = "negative",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self.name) and player.room:getTag("RoundCount") == 1
  end,
  on_use = function(self, event, target, player, data)
    player:gainAnExtraTurn()
  end,
}
local test2 = General(extension, "mouxusheng", "wu", 99, 99, General.Female)
test2.shield = 5
test2:addSkill("rende")
test2:addSkill(cheat)
test2:addSkill(control)
test2:addSkill(test_vs)
--test2:addSkill(test_trig)
test2:addSkill(damage_maker)
test2:addSkill(change_hero)
test2:addSkill(test_zhenggong)

Fk:loadTranslationTable{
  ["test_p_0"] = "测试包",
  ["test"] = "测试",
  ["test_filter"] = "破军",
  [":test_filter"] = "你的点数大于11的牌视为无中生有。",
  ["mouxusheng"] = "谋徐盛",
  -- ["cheat"] = "小开",
  [":cheat"] = "出牌阶段，你可以获得一张想要的牌。",
  --["#test_trig-ask"] = "你可弃置一张手牌",
  ["control"] = "控制",
  [":control"] = "出牌阶段，你可以控制/解除控制若干名其他角色。",

  ["test_vs"] = "视为",
  [":test_vs"] = "你可以将牌当包含无懈在内的某张锦囊使用。",

  ["damage_maker"] = "制伤",
  [":damage_maker"] = "出牌阶段，你可以进行一次伤害制造器。",

  ["change_hero"] = "变更",
  [":change_hero"] = "出牌阶段，你可以变更一名角色武将牌。",

  ["test_zhenggong"] = "迅测",
  [":test_zhenggong"] = "锁定技，首轮开始时，你执行额外的回合。",
}

return { extension }
