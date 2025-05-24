local change_hero = fk.CreateSkill{
  name = "change_hero",
}

Fk:loadTranslationTable{
  ["change_hero"] = "变更",
  [":change_hero"] = "出牌阶段，你可以变更一名角色武将牌。",
  ["$change_hero"] = "敌军色厉内荏，可筑假城以退敌！",
}

change_hero:addEffect("active", {
  can_use = Util.TrueFunc,
  card_filter = Util.FalseFunc,
  card_num = 0,
  target_filter = function(self, player, to_select, selected)
    return #selected < 1
  end,
  target_num = 1,
  interaction = function(self)
    return UI.ComboBox {
      choices = { "mainGeneral",  "deputyGeneral"},
    }
  end,
  on_use = function(self, room, effect)
    local from = effect.from
    local target = effect.tos[1]
    local choice = self.interaction.data
    local generals = room:getNGenerals(8)
    local general = room:askToChooseGeneral(from, {generals = generals, n = 1})
    table.removeOne(generals, general)
    room:changeHero(target, general, false, choice == "deputyGeneral", true)
    room:returnToGeneralPile(generals)
  end,
})

return change_hero
