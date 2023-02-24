local discardSkill = fk.CreateActiveSkill{
  name = "discard_skill",
  card_filter = function(self, to_select, selected)
    if #selected >= self.num then
      return false
    end

    if not self.include_equip then
      return Fk:currentRoom():getCardArea(to_select) ~= Player.Equip
    end

    return true
  end,
  min_card_num = function(self) return self.min_num end,
  max_card_num = function(self) return self.num end,
}

local choosePlayersSkill = fk.CreateActiveSkill{
  name = "choose_players_skill",
  card_filter = function()
    return false
  end,
  target_filter = function(self, to_select, selected)
    if #selected < self.num then
      return table.contains(self.targets, to_select)
    end
  end,
  min_target_num = function(self) return self.min_num end,
  max_target_num = function(self) return self.num end,
}

Fk:loadTranslationTable{
  ["discard_skill"] = "弃牌",
  ["choose_players_skill"] = "选择角色",
}

AuxSkills = {
  discardSkill,
  choosePlayersSkill,
}
