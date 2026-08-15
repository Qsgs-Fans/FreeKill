local skill_name = "discard_skill"

local _skill = fk.CreateSkill{
  name = skill_name,
}

_skill:addEffect('active', {
  card_filter = function(self, player, to_select, selected)
    if #selected >= self.num then
      return false
    end

    if Fk:currentRoom():getCardArea(to_select) == Card.PlayerSpecial then
      local pile = ""
      for p, t in pairs(player.special_cards) do
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
      if skill:prohibitDiscard(player, card) then
        return false
      end
    end
    if Fk.currentResponseReason == "phase_discard" then
      ---@type MaxCardsSkill[]
      status_skills = Fk:currentRoom().status_skills[MaxCardsSkill] or Util.DummyTable
      for _, sk in ipairs(status_skills) do
        if sk:excludeFrom(player, card) then
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

_skill:addAI(Fk.Ltk.AI.newActiveStrategy {
  think = function(self, ai)
    local data = ai.data[4]
    local skill = Fk.skills[data.skillName] or _skill
    local strategy = ai:findStrategyOfSkill(Fk.Ltk.AI.DiscardStrategy, skill.name)
    if not strategy then
      strategy = ai:findStrategyOfSkill(Fk.Ltk.AI.DiscardStrategy, _skill.name)
      ---@cast strategy -nil
    end

    local cards, benefit = strategy:chooseCards(ai)
    if cards then
      return { cards, {} }, benefit or 0
    end
  end,
})

_skill:addAI(Fk.Ltk.AI.newDiscardStrategy {
  choose_cards = function(self, ai)
    local data = ai.data[4] -- extra_data
    local available_cards = ai:getEnabledCards()

    local num = data.num
    local min_num = ai.data[3] and 0 or data.min_num

    ai:sortCards(available_cards, "keep_value")
    if ai._debug then
      verbose(0, "[默认弃牌AI] 已完成卡牌的排序，排序后的卡牌为%s", table.concat(
        table.map(available_cards, function(id)
          local cd = Fk:getCardById(id)
          local log = cd:toLogString()
          local v = ai:getCardValue(id)
          return ("%s(id=%s, v=%s)"):format(log, id, v)
        end), ","))
    end
    local cards = table.slice(available_cards, 1, min_num + 1)
    local benefit = -ai:getBenefitOfEvents(function(logic)
      logic:moveCardTo(cards, Card.DiscardPile, nil, fk.ReasonDiscard, ai.data[1], nil, false, ai.player)
    end)
    return cards, benefit
  end,
})

return _skill
