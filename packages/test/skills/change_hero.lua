local change_hero = fk.CreateSkill{
  name = "change_hero",
}

Fk:loadTranslationTable{
  ["change_hero"] = "变更",
  [":change_hero"] = "出牌阶段，你可以变更一名角色武将牌或其他属性。",
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
      choices = { "mainGeneral",  "deputyGeneral", "Gender", "Kingdom" },
    }
  end,
  on_use = function(self, room, effect)
    local from = effect.from
    local target = effect.tos[1]
    local choice = self.interaction.data
    if choice:endsWith("General") then
      local generals = room:getNGenerals(8)
      local general = room:askToChooseGeneral(from, {generals = generals, n = 1})
      local origin = choice == "deputyGeneral" and target.deputyGeneral or target.general
      if origin ~= "" then
        table.insertIfNeed(generals, origin)
      end
      room:returnToGeneralPile(generals)
      room:findGeneral(general)
      room:changeHero(target, general, false, choice == "deputyGeneral", true)
    elseif choice == "Gender" then
      local genders = { "male", "female", "bigender", "agender" }
      room:setPlayerProperty(target, "gender", room:askToChoice(from, {choices = genders, skill_name = "change_hero"}))
    elseif choice == "Kingdom" then
      local kingdoms = { "wei", "shu", "wu", "qun" }
      for _, g in pairs(Fk.generals) do
        if not g.total_hidden then
          table.insertIfNeed(kingdoms, g.kingdom)
        end
      end
      room:setPlayerProperty(target, "kingdom", room:askToChoice(from, {choices = kingdoms, skill_name = "change_hero"}))
    end
  end,
})

return change_hero
