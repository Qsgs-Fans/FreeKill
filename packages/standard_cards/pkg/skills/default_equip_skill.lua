local skill = fk.CreateSkill{
  name = "default_equip_skill",
}

skill:addEffect("cardskill", {
  prompt = function(self, player, selected_cards, _)
    if not selected_cards or #selected_cards == 0 then return " " end
    return "#default_equip_skill:::" .. Fk:getCardById(selected_cards[1]).name
  end,
  mod_target_filter = function(self, player, to_select, selected, card, distance_limited)
    return #to_select:getAvailableEquipSlots(card.sub_type) > 0
  end,
  can_use = Util.CanUseToSelf,
})

skill:addAI(
  {
    on_use = function(self, logic, effect)
      self.skill:onUse(logic, effect)
    end,

    think = function(self, ai)
      local estimate_val = self:getEstimatedBenefit(ai)
      local cards = ai:getEnabledCards()
      cards = table.filter(cards, function(cid) return Fk:getCardById(cid).skill.name == "default_equip_skill" end)
      cards = table.random(cards, math.min(#cards, 5)) --[[@as integer[] ]]
      -- local cid = table.random(cards)

      local best_ret, best_val = "", -100000
      for _, cid in ipairs(cards) do
        ai:selectCard(cid, true)
        local ret, val = self:chooseTargets(ai)
        val = val or -100000
        if best_val < val then
          best_ret, best_val = ret, val
        end
        if best_val >= estimate_val then break end
        ai:unSelectAll()
      end

      if best_ret and best_ret ~= "" then
        if best_val < 0 then
          return ""
        end

        best_ret = { card = ai:getSelectedCard().id, targets = best_ret }
      end

      return best_ret, best_val
    end,
  }, "__card_skill"
)

skill:addTest(function(room, me)
  local spear = room:printCard("spear")

  lu.assertIsTrue(me:canUse(spear))
  FkTest.runInRoom(function()
    room:abortPlayerArea(me, Player.WeaponSlot)
  end)
  lu.assertIsFalse(me:canUse(spear))
end)

return skill
