local discardSkill = fk.CreateActiveSkill{
  name = "discard_skill",
  card_filter = function(self, to_select, selected)
    if #selected >= self.num then
      return false
    end

    local checkpoint = true
    if not self.include_equip then
      checkpoint = checkpoint and (Fk:currentRoom():getCardArea(to_select) ~= Player.Equip)
    end

    if self.pattern ~= "" then
      checkpoint = checkpoint and (Exppattern:Parse(self.pattern):match(Fk:getCardById(to_select)))
    end
    return checkpoint
  end,
  min_card_num = function(self) return self.min_num end,
  max_card_num = function(self) return self.num end,
}

local chooseCardsSkill = fk.CreateActiveSkill{
  name = "choose_cards_skill",
  expand_pile = function(self) return self.expand_pile end,
  card_filter = discardSkill.cardFilter,
  min_card_num = function(self) return self.min_num end,
  max_card_num = function(self) return self.num end,
}

local choosePlayersSkill = fk.CreateActiveSkill{
  name = "choose_players_skill",
  card_filter = function(self, to_select)
    return self.pattern ~= "" and Exppattern:Parse(self.pattern):match(Fk:getCardById(to_select))
  end,
  target_filter = function(self, to_select, selected, cards)
    if self.pattern ~= "" and #cards == 0 then return end
    if #selected < self.num then
      return table.contains(self.targets, to_select)
    end
  end,
  card_num = function(self) return self.pattern ~= "" and 1 or 0 end,
  min_target_num = function(self) return self.min_num end,
  max_target_num = function(self) return self.num end,
}

AuxSkills = {
  discardSkill,
  chooseCardsSkill,
  choosePlayersSkill,
}
