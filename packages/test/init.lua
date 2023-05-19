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

    local cardName = room:askForChoice(from, allCardNames, "cheat")
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
local test_active = fk.CreateActiveSkill{
  name = "test_active",
  can_use = function(self, player)
    return true
  end,
  card_filter = function(self, card)
    -- if self.interaction.data == "joy" then
      --local c = Fk:getCardById(card)
      --return Self:getPileNameOfId(card) == self.name and c.color == Card.Red
      return true
    -- end
  end,
  card_num = 2,
  target_filter = function() return true end,
  interaction = function()return UI.Spin {
    --choices = Fk.package_names,
    from=2,to=8,
    -- default = "guanyu",
  }end,
  on_use = function(self, room, effect)
    --room:doSuperLightBox("packages/test/qml/Test.qml")
    local from = room:getPlayerById(effect.from)
    --local to = room:getPlayerById(effect.tos[1])
    -- room:swapSeat(from, to)
    --from:control(to)
    local success, dat = room:askForUseViewAsSkill(from, "wusheng", nil, true)
    if success then
      local card = Fk.skills["wusheng"]:viewAs(dat.cards)
      room:useCard{
        from = from.id,
        tos = table.map(dat.targets, function(e) return {e} end),
        card = card,
      }
    end
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
      }
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
  events = {fk.Damage},
  on_use = function(self, event, target, player, data)
    player:drawCards(1, self.name)
    player.room.logic:breakTurn()
  end,
}
local test2 = General(extension, "mouxusheng", "wu", 4, 4, General.Female)
test2.shield = 4
test2:addSkill("rende")
test2:addSkill(cheat)
test2:addSkill(test_active)
test2:addSkill(test_vs)
test2:addSkill(test_trig)

Fk:loadTranslationTable{
  ["test_p_0"] = "测试包",
  ["test"] = "测试",
  ["test_filter"] = "破军",
  [":test_filter"] = "你的点数大于11的牌视为无中生有。",
  ["mouxusheng"] = "谋徐盛",
  --["cheat"] = "开挂",
  [":cheat"] = "出牌阶段，你可以获得一张想要的牌。",
}

return { extension }
