local skill_name = "choose_cards_skill"

local skill = fk.CreateSkill{
  name = skill_name,
}

skill:addEffect('active', {
  card_filter = function(self, player, to_select, selected)
    if #selected >= self.num then
      return false
    end

    if not table.contains(player:getCardIds("he"), to_select) then
      local pile = self:getPile(player)
      if not table.contains(pile, to_select) then return false end
    end

    local checkpoint = true
    local card = Fk:getCardById(to_select)

    if not self.include_equip then
      checkpoint = checkpoint and (Fk:currentRoom():getCardArea(to_select) ~= Player.Equip)
    end

    if self.pattern and self.pattern ~= "" then
      checkpoint = checkpoint and (Exppattern:Parse(self.pattern):match(card))
    end
    return checkpoint
  end,
  min_card_num = function(self, player) return self.min_num end,
  max_card_num = function(self, player) return self.num end,
})

return skill
