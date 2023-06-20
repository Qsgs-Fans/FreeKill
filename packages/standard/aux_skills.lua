-- SPDX-License-Identifier: GPL-3.0-or-later

local discardSkill = fk.CreateActiveSkill{
  name = "discard_skill",
  card_filter = function(self, to_select, selected)
    if #selected >= self.num then
      return false
    end

    local checkpoint = true
    local card = Fk:getCardById(to_select)

    local status_skills = Fk:currentRoom().status_skills[ProhibitSkill] or Util.DummyTable
    for _, skill in ipairs(status_skills) do
      if skill:prohibitDiscard(Self, card) then
        return false
      end
    end
    if Fk.currentResponseReason == "game_rule" then
      status_skills = Fk:currentRoom().status_skills[MaxCardsSkill] or Util.DummyTable
      for _, skill in ipairs(status_skills) do
        if skill:excludeFrom(Self, card) then
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
  min_card_num = function(self) return self.min_num end,
  max_card_num = function(self) return self.num end,
}

local chooseCardsSkill = fk.CreateActiveSkill{
  name = "choose_cards_skill",
  expand_pile = function(self) return self.expand_pile end,
  card_filter = function(self, to_select, selected)
    if #selected >= self.num then
      return false
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

local maxCardsSkill = fk.CreateMaxCardsSkill{
  name = "max_cards_skill",
  global = true,
  correct_func = function(self, player)
    return
      player:getMark(MarkEnum.AddMaxCards) +
      player:getMark(MarkEnum.AddMaxCardsInTurn) -
      player:getMark(MarkEnum.MinusMaxCards) -
      player:getMark(MarkEnum.MinusMaxCardsInTurn)
  end,
}

local choosePlayersToMoveCardInBoardSkill = fk.CreateActiveSkill{
  name = "choose_players_to_move_card_in_board",
  target_num = 2,
  card_filter = function(self, to_select)
    return false
  end,
  target_filter = function(self, to_select, selected, cards)
    local target = Fk:currentRoom():getPlayerById(to_select)
    if #selected > 0 then
      return Fk:currentRoom():getPlayerById(selected[1]):canMoveCardsInBoardTo(target, self.flag)
    end

    return #target:getCardIds({ Player.Equip, Player.Judge }) > 0
  end,
}

local uncompulsoryInvalidity = fk.CreateInvaliditySkill {
  name = "uncompulsory_invalidity",
  global = true,
  invalidity_func = function(self, from, skill)
    return
      (skill.frequency ~= Skill.Compulsory and skill.frequency ~= Skill.Wake) and
      not (skill:isEquipmentSkill() or skill.name:endsWith("&")) and
      (
        from:getMark(MarkEnum.UncompulsoryInvalidity) ~= 0 or
        table.find(MarkEnum.TempMarkSuffix, function(s)
          return from:getMark(MarkEnum.UncompulsoryInvalidity .. s) ~= 0
        end)
      )
  end
}

AuxSkills = {
  discardSkill,
  chooseCardsSkill,
  choosePlayersSkill,
  maxCardsSkill,
  choosePlayersToMoveCardInBoardSkill,
  uncompulsoryInvalidity,
}
