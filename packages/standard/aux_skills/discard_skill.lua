local skill_name = "discard_skill"

local skill = fk.CreateSkill{
  name = skill_name,
}

skill:addEffect('active', {
  card_filter = function(self, player, to_select, selected)
    if #selected >= self.num then
      return false
    end

    if Fk:currentRoom():getCardArea(to_select) == Card.PlayerSpecial then
      local pile = ""
      for p, t in pairs(Self.special_cards) do
        if table.contains(t, to_select) then
          pile = p
          break
        end
      end
      if not string.find(self.pattern or "", pile) then return false end
    end

    local checkpoint = true
    local card = Fk:getCardById(to_select)

    local status_skills = Fk:currentRoom().status_skills[ProhibitSkill] or Util.DummyTable
    for _, skill in ipairs(status_skills) do
      if skill:prohibitDiscard(Self, card) then
        return false
      end
    end
    if Fk.currentResponseReason == "phase_discard" then
      ---@type MaxCardsSkill[]
      status_skills = Fk:currentRoom().status_skills[MaxCardsSkill] or Util.DummyTable
      for _, sk in ipairs(status_skills) do
        if sk:excludeFrom(Self, card) then
          return false
        end
      end
    end

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
