-- SPDX-License-Identifier: GPL-3.0-or-later

local extension = Package("test_p_0")
extension.extensionName = "test"

local cheat = fk.CreateActiveSkill{
  name = "cheat",
  anim_type = "drawcard",
  prompt = "#cheat",
  can_use = function(self, player)
    return true
  end,
  card_filter = function(self, card)
    return false
  end,
  target_num = 0,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    local cardType = { 'basic', 'trick', 'equip' }
    local cardTypeName = room:askForChoice(from, cardType, "cheat")
    local card_types = {Card.TypeBasic, Card.TypeTrick, Card.TypeEquip}
    cardType = card_types[table.indexOf(cardType, cardTypeName)]

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

    local cardName = room:askForChoice(from, allCardNames, "cheat")
    local toGain -- = room:printCard(cardName, Card.Heart, 1)
    if #allCardMapper[cardName] > 0 then
      toGain = allCardMapper[cardName][math.random(1, #allCardMapper[cardName])]
    end

    -- from:addToPile(self.name, toGain, true, self.name)
    -- room:setCardMark(Fk:getCardById(toGain), "@@test_cheat-phase", 1)
    -- room:setCardMark(Fk:getCardById(toGain), "@@test_cheat-inhand", 1)
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
      -- p(room:askForPoxi(from, "test", {
      --   { "你自己", from:getCardIds "h" },
      --   { "对方", to:getCardIds "h" },
      -- }))
      -- room:setPlayerMark(from, "@$a", {1,2,3})
      -- room:setPlayerMark(from, "@$b", {'slash','duel','axe'})
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
--[[
Fk:addPoxiMethod{
  name = "test",
  card_filter = function(to_select, selected, data)
    local s = Fk:getCardById(to_select).suit
    for _, id in ipairs(selected) do
      if Fk:getCardById(id).suit == s then return false end
    end
    return true
  end,
  feasible = function(selected, data)
    return #selected == 0 or #selected == 4
  end,
  prompt = "魄袭：选你们俩手牌总共四个花色，或者不选直接按确定按钮"
}
--]]
local test_vs = fk.CreateViewAsSkill{
  name = "test_vs",
  pattern = "nullification",
  prompt = "#test_vs",
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
  prompt = "#damage_maker",
  can_use = function(self, player)
    return true
  end,
  card_filter = function(self, card)
    return false
  end,
  card_num = 0,
  target_filter = function(self, to_select, selected)
    if self.interaction.data == "revive" then return false end
    return #selected < 2
  end,
  min_target_num = function(self)
    return self.interaction.data == "revive" and 0 or 1
  end,
  max_target_num = function(self)
    return self.interaction.data == "revive" and 0 or 2
  end,
  interaction = function() return UI.ComboBox {
    choices = {"normal_damage", "thunder_damage", "fire_damage", "ice_damage", "lose_hp", "heal_hp", "lose_max_hp", "heal_max_hp", "revive"}
  } end,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    local victim = #effect.tos > 0 and room:getPlayerById(effect.tos[1])
    local target = #effect.tos > 1 and room:getPlayerById(effect.tos[2])
    local choice = self.interaction.data
    local number
    if choice ~= "revive" then
      local choices = {}
      for i = 1, 99 do
        table.insert(choices, tostring(i))
      end
      number = tonumber(room:askForChoice(from, choices, self.name, nil))
    end
    if target then from = target end
    if choice == "heal_hp" then
      room:recover{
        who = victim,
        num = number,
        recoverBy = from,
        skillName = self.name
      }
    elseif choice == "heal_max_hp" then
      room:changeMaxHp(victim, number)
    elseif choice == "lose_max_hp" then
      room:changeMaxHp(victim, -number)
    elseif choice == "lose_hp" then
      room:loseHp(victim, number, self.name)
    elseif choice == "revive" then
      local targets = table.map(table.filter(room.players, function(p) return p.dead end), function(p) return "seat#" .. tostring(p.seat) end)
      if #targets > 0 then
        targets = room:askForChoice(from, targets, self.name, "#revive-ask")
        if targets then
          target = tonumber(string.sub(targets, 6))
          for _, p in ipairs(room.players) do
            if p.seat == target then
              room:revivePlayer(p, true)
              break
            end
          end
        end
      end
    else
      local choices = {"normal_damage", "thunder_damage", "fire_damage", "ice_damage"}
      room:damage({
        from = from,
        to = victim,
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
  interaction = function(self)
    return UI.ComboBox {
      choices = { "mainGeneral",  "deputyGeneral"},
    }
  end,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    local choice = self.interaction.data
    local generals = room:getNGenerals(8)
    local general = room:askForGeneral(from, generals, 1)
    if general == nil then
      general = table.random(generals)
    end
    table.removeOne(generals, general)
    room:changeHero(target, general, false, choice == "deputyGeneral", true)
    room:returnToGeneralPile(generals)
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
local test_feichu = fk.CreateActiveSkill{
  name = "test_feichu",
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
    local eqipSlots = from:getAvailableEquipSlots()
    table.insert(eqipSlots, Player.JudgeSlot)
    room:abortPlayerArea(from, eqipSlots)
  end,
}
local test2 = General(extension, "mouxusheng", "wu", 4, 4, General.Female)
test2.shield = 3
test2.hidden = true
test2:addSkill("rende")
test2:addSkill(cheat)
test2:addSkill(control)
--test2:addSkill(test_vs)
--test2:addSkill(test_trig)
test2:addSkill(damage_maker)
test2:addSkill(test_zhenggong)
test2:addSkill(change_hero)
-- test2:addSkill(test_feichu)

local shibing = General(extension, "blank_shibing", "qun", 5)
shibing.hidden = true
Fk:loadTranslationTable{
  ["blank_shibing"] = "男士兵",
}

local nvshibing = General(extension, "blank_nvshibing", "qun", 5, 5, General.Female)
Fk:loadTranslationTable{
  ["blank_nvshibing"] = "女士兵",
}
nvshibing.hidden = true

Fk:loadTranslationTable{
  ["test_p_0"] = "测试包",
  ["test"] = "测试",
  ["test_filter"] = "破军",
  [":test_filter"] = "你的点数大于11的牌视为无中生有。",
  ["mouxusheng"] = "谋徐盛",
  -- ["cheat"] = "小开",
  [":cheat"] = "出牌阶段，你可获得想要的牌。",
  ["#cheat"] = "cheat：你可以获得一张想要的牌",
  ["$cheat"] = "喝啊！",
  -- ["@@test_cheat-phase"] = "苦肉",
  -- ["@@test_cheat-inhand"] = "连营",
  --["#test_trig-ask"] = "你可弃置一张手牌",
  ["control"] = "控制",
  [":control"] = "出牌阶段，你可以控制/解除控制若干名其他角色。",
  ["$control"] = "战将临阵，斩关刈城！",

  ["test_vs"] = "视为",
  [":test_vs"] = "你可以将牌当包含无懈在内的某张锦囊使用。",
  ["#test_vs"] = "视为：你可以学习锦囊牌的用法",

  ["damage_maker"] = "制伤",
  [":damage_maker"] = "出牌阶段，你可以进行一次伤害制造器。",
  ["#damage_maker"] = "制伤：选择一名小白鼠，可选另一名角色做伤害来源（默认谋徐盛）",
  ["#revive-ask"] = "复活一名角色！",
  ["$damage_maker"] = "区区数百魏军，看我一击灭之！",

  ["test_zhenggong"] = "迅测",
  [":test_zhenggong"] = "锁定技，首轮开始时，你执行额外的回合。",
  ["$test_zhenggong"] = "今疑兵之计，已搓敌兵心胆，其安敢侵近！",

  ["change_hero"] = "变更",
  [":change_hero"] = "出牌阶段，你可以变更一名角色武将牌。",
  ["$change_hero"] = "敌军色厉内荏，可筑假城以退敌！",

  ["~mouxusheng"] = "来世，愿再为我江东之臣……",
}

return { extension }
