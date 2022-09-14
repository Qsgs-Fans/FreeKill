local discardSkill = fk.CreateActiveSkill{
  name = "discard_skill",
  card_filter = function(self, to_select, selected)
    if #selected >= self.num then
      return false
    end

    return true
  end,
  feasible = function(self, _, selected)
    return #selected >= self.min_num
  end,
}

local choosePlayersSkill = fk.CreateActiveSkill{
  name = "choose_players_skill",
}

Fk:loadTranslationTable{
  ["discard_skill"] = "弃牌",
  ["choose_players_skill"] = "选择角色",
}

AuxSkills = {
  discardSkill
}
