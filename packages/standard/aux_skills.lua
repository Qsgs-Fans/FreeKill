local discardSkill = fk.CreateActiveSkill{
  name = "discard_skill",
  card_filter = function(self, to_select, selected)
    if #selected >= self.num then
      return false
    end

    if not self.include_equip then
      return ClientInstance:getCardArea(to_select) ~= Player.Equip
    end

    return true
  end,
  feasible = function(self, _, selected)
    return #selected >= self.min_num
  end,
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
  feasible = function(self, selected)
    return #selected >= self.min_num
  end,
}

Fk:loadTranslationTable{
  ["discard_skill"] = "弃牌",
  ["choose_players_skill"] = "选择角色",
}

AuxSkills = {
  discardSkill,
  choosePlayersSkill,
}
