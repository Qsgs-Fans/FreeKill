--[[
fk.ai_card.thunder__slash = fk.ai_card.slash
fk.ai_use_play.thunder__slash = fk.ai_use_play.slash
fk.ai_card.fire__slash = fk.ai_card.slash
fk.ai_use_play.fire__slash = fk.ai_use_play.slash
fk.ai_card.analeptic = {
  intention = 60, -- 身份值
  value = 5,      -- 卡牌价值
  priority = 3    -- 使用优先值
}

fk.ai_use_play["analeptic"] = function(self, card)
  local cards = table.map(self.player:getCardIds("&he"), function(id)
    return Fk:getCardById(id)
  end)
  self:sortValue(cards)
  for _, sth in ipairs(self:getActives("slash")) do
    local slash = nil
    if sth:isInstanceOf(Card) then
      if sth.skill:canUse(self.player, sth) and not self.player:prohibitUse(sth) then
        slash = sth
      end
    else
      local selected = {}
      for _, c in ipairs(cards) do
        if sth:cardFilter(c.id, selected) then
          table.insert(selected, c.id)
        end
      end
      local tc = sth:viewAs(selected)
      if tc and tc:matchPattern("slash") and tc.skill:canUse(self.player, tc) and not self.player:prohibitUse(tc) then
        slash = tc
      end
    end
    if slash then
      fk.ai_use_play.slash(self, slash)
      if self.use_id then
        self.use_id = card.id
        self.use_tos = {}
        break
      end
    end
  end
end

fk.ai_card.iron_chain = {
  intention = function(self, card, from)
    if self.player.chained then
      return -80
    end
    return 80
  end,         -- 身份值
  value = 2,   -- 卡牌价值
  priority = 3 -- 使用优先值
}

fk.ai_use_play["iron_chain"] = function(self, card)
  for _, p in ipairs(self.friends) do
    if card.skill:targetFilter(p.id, self.use_tos, {}, card) and p.chained then
      table.insert(self.use_tos, p.id)
    end
  end
  self:sort(self.enemies)
  for _, p in ipairs(self.enemies) do
    if card.skill:targetFilter(p.id, self.use_tos, {}, card) and not p.chained then
      table.insert(self.use_tos, p.id)
    end
  end
  if #self.use_tos < 2 then
    self.use_tos = {}
  else
    self.use_id = card.id
  end
end

fk.ai_use_play["recast"] = function(self, card)
  if self.command == "PlayCard" then
    self.use_id = card.id
    self.special_skill = "recast"
  end
end

fk.ai_card.fire_attack = {
  intention = 90, -- 身份值
  value = 3,      -- 卡牌价值
  priority = 4    -- 使用优先值
}

fk.ai_use_play["fire_attack"] = function(self, card)
  self:sort(self.enemies)
  for _, p in ipairs(self.enemies) do
    if card.skill:targetFilter(p.id, self.use_tos, {}, card) and #self.player:getCardIds("h") > 2 then
      self.use_id = card.id
      table.insert(self.use_tos, p.id)
    end
  end
end

fk.ai_discard["fire_attack_skill"] = function(self, min_num, num, include_equip, cancelable, pattern, prompt)
  local use = self:eventData("UseCard")
  for _, p in ipairs(TargetGroup:getRealTargets(use.tos)) do
    if self:isEnemy(p) then
      local cards = table.map(self.player:getCardIds("h"), function(id)
        return Fk:getCardById(id)
      end)
      local exp = Exppattern:Parse(pattern)
      cards = table.filter(cards, function(c)
        return exp:match(c)
      end)
      if #cards > 0 then
        self:sortValue(cards)
        return { cards[1].id }
      end
    end
  end
end

fk.ai_nullification.fire_attack = function(self, card, to, from, positive)
  if positive then
    if self:isFriend(to) and #to:getCardIds("h") > 0 and #from:getCardIds("h") > 0 then
      if #self.avail_cards > 1 or self:isWeak(to) or to.id == self.player.id then
        self.use_id = self.avail_cards[1]
      end
    end
  else
    if self:isEnemy(to) and #to:getCardIds("h") > 0 and #from:getCardIds("h") > 1 then
      if #self.avail_cards > 1 or self:isWeak(to) then
        self.use_id = self.avail_cards[1]
      end
    end
  end
end

fk.ai_card.fire_attack = {
  intention = 120, -- 身份值
  value = 2,       -- 卡牌价值
  priority = 2     -- 使用优先值
}

fk.ai_use_play["supply_shortage"] = function(self, card)
  self:sort(self.enemies)
  for _, p in ipairs(self.enemies) do
    if card.skill:targetFilter(p.id, self.use_tos, {}, card) and not p.chained then
      self.use_id = card.id
      table.insert(self.use_tos, p.id)
    end
  end
end

fk.ai_nullification.supply_shortage = function(self, card, to, from, positive)
  if positive then
    if self:isFriend(to) then
      if #self.avail_cards > 1 or self:isWeak(to) or to.id == self.player.id then
        self.use_id = self.avail_cards[1]
      end
    end
  else
    if self:isEnemy(to) then
      if #self.avail_cards > 1 or self:isWeak(to) then
        self.use_id = self.avail_cards[1]
      end
    end
  end
end

fk.ai_card.supply_shortage = {
  intention = 130, -- 身份值
  value = 2,       -- 卡牌价值
  priority = 1     -- 使用优先值
}

fk.ai_skill_invoke["#fan_skill"] = function(self)
  local use = self:eventData("UseCard")
  for _, p in ipairs(TargetGroup:getRealTargets(use.tos)) do
    if not self:isFriend(p) then
      return true
    end
  end
end
--]]
