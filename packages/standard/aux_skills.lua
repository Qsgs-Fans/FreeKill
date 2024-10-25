-- SPDX-License-Identifier: GPL-3.0-or-later

local discardSkill = fk.CreateActiveSkill{
  name = "discard_skill",
  card_filter = function(self, to_select, selected)
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
  card_filter = function(self, to_select, selected)
    if #selected >= self.num then
      return false
    end

    if Fk:currentRoom():getCardArea(to_select) == Card.PlayerSpecial then
      if not string.find(self.pattern or "", self.expand_pile or "") then return false end
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
  card_filter = function(self, to_select, selected)
    return self.pattern ~= "" and Exppattern:Parse(self.pattern):match(Fk:getCardById(to_select)) and #selected == 0
  end,
  target_filter = function(self, to_select, selected, cards)
    if self.pattern ~= "" and #cards == 0 then return end
    if #selected < self.num then
      return table.contains(self.targets, to_select)
    end
  end,
  target_tip = function(self, to_select, selected, selected_cards, card, selectable, extra_data)
    if self.targetTipName then
      local targetTip = Fk.target_tips[self.targetTipName]
      assert(targetTip)
      return targetTip.target_tip(self, to_select, selected, selected_cards, card, selectable, extra_data)
    end
  end,
  card_num = function(self) return self.pattern ~= "" and 1 or 0 end,
  min_target_num = function(self) return self.min_num end,
  max_target_num = function(self) return self.num end,
}

local exChooseSkill = fk.CreateActiveSkill{
  name = "ex__choose_skill",
  card_filter = function(self, to_select, selected)
    if #selected >= self.max_c_num then return false end

    if Fk:currentRoom():getCardArea(to_select) == Card.PlayerSpecial then
      if not string.find(self.pattern or "", self.expand_pile or "") then return false end
    end

    local checkpoint = true
    local card = Fk:getCardById(to_select)


    if self.pattern and self.pattern ~= "" then
      checkpoint = checkpoint and (Exppattern:Parse(self.pattern):match(card))
    end
    return checkpoint
  end,
  target_filter = function(self, to_select, selected, cards)
    if #cards < self.min_c_num then return end
    if #selected < self.max_t_num then
      return table.contains(self.targets, to_select)
    end
  end,
  target_tip = function(self, to_select, selected, selected_cards, card, selectable, extra_data)
    if self.targetTipName then
      local targetTip = Fk.target_tips[self.targetTipName]
      assert(targetTip)
      return targetTip.target_tip(self, to_select, selected, selected_cards, card, selectable, extra_data)
    end
  end,
  min_target_num = function(self) return self.min_t_num end,
  max_target_num = function(self) return self.max_t_num end,
  min_card_num = function(self) return self.min_c_num end,
  max_card_num = function(self) return self.max_c_num end,
}

local maxCardsSkill = fk.CreateMaxCardsSkill{
  name = "max_cards_skill",
  global = true,
  correct_func = function(self, player)
    local function getMark(markname)
      local v = 0
      for mark, value in pairs(player.mark) do
        if mark == markname then
          v = v + value
        elseif mark:startsWith(markname .. "-") then
          for _, suffix in ipairs(MarkEnum.TempMarkSuffix) do
            if mark:find(suffix, 1, true) then
              v = v + value
              break
            end
          end
        end
      end
      return v
    end
    return
      getMark(MarkEnum.AddMaxCards) -
      getMark(MarkEnum.MinusMaxCards)
  end,
}

local distributionSelectSkill = fk.CreateActiveSkill{
  name = "distribution_select_skill",
  mute = true,
  min_card_num = 1,
  card_filter = function(self, to_select, selected)
    return #selected < self.max_num and table.contains(self.cards, to_select)
  end,
  target_num = 1,
  target_filter = function(self, to_select, selected, selected_cards)
    return #selected == 0 and #selected_cards > 0 and table.contains(self.targets, to_select)
    and #selected_cards <= (self.residued_list[string.format("%d", to_select)] or 0)
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
      return Fk:currentRoom():getPlayerById(selected[1]):canMoveCardsInBoardTo(target, self.flag, self.excludeIds)
    end

    local fromAreas = { Player.Equip, Player.Judge }
    if self.flag == "e" then
      fromAreas = { Player.Equip }
    elseif self.flag == "j" then
      fromAreas = { Player.Judge }
    end

    return #table.filter(target:getCardIds(fromAreas), function(id)
      return not table.contains((type(self.excludeIds) == "table" and self.excludeIds or {}), id)
    end) > 0
  end,
}

local uncompulsoryInvalidity = fk.CreateInvaliditySkill {
  name = "uncompulsory_invalidity",
  global = true,
  invalidity_func = function(self, from, skill)
    ---@param object Card|Player
    ---@param markname string
    ---@param suffixes string[]
    ---@return boolean
    local function hasMark(object, markname, suffixes)
      if not object then return false end
      for mark, _ in pairs(object.mark) do
        if mark == markname then return true end
        if mark:startsWith(markname .. "-") then
          for _, suffix in ipairs(suffixes) do
            if mark:find(suffix, 1, true) then return true end
          end
        end
      end
      return false
    end
    return
      (skill.frequency ~= Skill.Compulsory and skill.frequency ~= Skill.Wake) and
      skill:isPlayerSkill(from) and
      hasMark(from, MarkEnum.UncompulsoryInvalidity, MarkEnum.TempMarkSuffix)
      -- (
      --   from:getMark(MarkEnum.UncompulsoryInvalidity) ~= 0 or
      --   table.find(MarkEnum.TempMarkSuffix, function(s)
      --     return from:getMark(MarkEnum.UncompulsoryInvalidity .. s) ~= 0
      --   end)
      -- )
  end
}

local revealProhibited = fk.CreateInvaliditySkill {
  name = "reveal_prohibited",
  global = true,
  invalidity_func = function(self, from, skill)
    local generals = {}
    if type(from:getMark(MarkEnum.RevealProhibited)) == "table" then
      generals = from:getMark(MarkEnum.RevealProhibited)
    end

    for mark, value in pairs(from.mark) do
      if mark:startsWith(MarkEnum.RevealProhibited .. "-") and type(value) == "table" then
        for _, suffix in ipairs(MarkEnum.TempMarkSuffix) do
          if mark:find(suffix, 1, true) then
            for _, g in ipairs(value) do
              table.insertIfNeed(generals, g)
            end
          end
        end
      end
    end
    -- for _, m in ipairs(table.map(MarkEnum.TempMarkSuffix, function(s)
    --     return from:getMark(MarkEnum.RevealProhibited .. s)
    --   end)) do
    --   if type(m) == "table" then
    --     for _, g in ipairs(m) do
    --       table.insertIfNeed(generals, g)
    --     end
    --   end
    -- end

    if #generals == 0 then return false end
    local sname = skill.name
    for _, g in ipairs(generals) do
      if (g == "m" and from.general == "anjiang") or (g == "d" and from.deputyGeneral == "anjiang") then
        local generalName = g == "m" and from:getMark("__heg_general") or from:getMark("__heg_deputy")
        local general = Fk.generals[generalName]
        if table.contains(general:getSkillNameList(true), sname) then
          return true
        end
      end
    end
    return false
  end
}

-- 亮将
local revealSkill = fk.CreateActiveSkill{
  name = "reveal_skill&",
  prompt = "#reveal_skill&",
  interaction = function(self)
    local choiceList = {}
    if (Self.general == "anjiang" and not Self:prohibitReveal()) then
      local general = Fk.generals[Self:getMark("__heg_general")]
      for _, sname in ipairs(general:getSkillNameList(true)) do
        local s = Fk.skills[sname]
        if s.frequency == Skill.Compulsory and s.relate_to_place ~= "m" then
          table.insert(choiceList, "revealMain:::" .. general.name)
          break
        end
      end
    end
    if (Self.deputyGeneral == "anjiang" and not Self:prohibitReveal(true)) then
      local general = Fk.generals[Self:getMark("__heg_deputy")]
      for _, sname in ipairs(general:getSkillNameList(true)) do
        local s = Fk.skills[sname]
        if s.frequency == Skill.Compulsory and s.relate_to_place ~= "d" then
          table.insert(choiceList, "revealDeputy:::" .. general.name)
          break
        end
      end
    end
    if #choiceList == 0 then return false end
    return UI.ComboBox { choices = choiceList }
  end,
  target_num = 0,
  card_num = 0,
  card_filter = Util.FalseFunc,
  on_use = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    local choice = self.interaction.data
    if not choice then return false
    elseif choice:startsWith("revealMain") then player:revealGeneral(false)
    elseif choice:startsWith("revealDeputy") then player:revealGeneral(true) end
  end,
  can_use = function(self, player)
    if (player.general == "anjiang" and not player:prohibitReveal()) then
      local general = Fk.generals[player:getMark("__heg_general")]
      for _, sname in ipairs(general:getSkillNameList(true)) do
        local s = Fk.skills[sname]
        if s.frequency == Skill.Compulsory and s.relate_to_place ~= "m" then
          return true
        end
      end
    end
    if (player.deputyGeneral == "anjiang" and not player:prohibitReveal(true)) then
      local general = Fk.generals[player:getMark("__heg_deputy")]
      for _, sname in ipairs(general:getSkillNameList(true)) do
        local s = Fk.skills[sname]
        if s.frequency == Skill.Compulsory and s.relate_to_place ~= "d" then
          return true
        end
      end
    end
    return false
  end
}

AuxSkills = {
  discardSkill,
  chooseCardsSkill,
  choosePlayersSkill,
  exChooseSkill,
  distributionSelectSkill,
  maxCardsSkill,
  choosePlayersToMoveCardInBoardSkill,
  uncompulsoryInvalidity,
  revealProhibited,
  revealSkill
}
