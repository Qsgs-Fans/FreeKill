fk.ai_card.slash = {
  intention = 100, -- 身份值
  value = 4,       -- 卡牌价值
  priority = 2.5   -- 使用优先值
}
fk.ai_card.peach = {
  intention = -150,
  value = 10,
  priority = 0.5
}
fk.ai_card.dismantlement = {
  intention = function(self, card, from)
    if #self.player.player_cards[Player.Judge] < 1 then
      return 80
    elseif fk.ai_role[from.id] == "neutral" then
      return 30
    end
  end,
  value = 3.5,
  priority = 10.5
}
fk.ai_card.snatch = {
  intention = function(self, card, from)
    if #self.player.player_cards[Player.Judge] < 1 then
      return 80
    elseif fk.ai_role[from.id] == "neutral" then
      return 30
    end
  end,
  value = 4.5,
  priority = 10.4
}
fk.ai_card.duel = {
  intention = 120,
  value = 4.5,
  priority = 3.5
}
fk.ai_card.collateral = {
  intention = 20,
  value = 3,
  priority = 4.5
}
fk.ai_card.ex_nihilo = {
  intention = -200,
  value = 8,
  priority = 10
}
fk.ai_card.savage_assault = {
  intention = 20,
  value = 2,
  priority = 4
}
fk.ai_card.archery_attack = {
  intention = 30,
  value = 2,
  priority = 3
}
fk.ai_card.god_salvation = {
  intention = function(self, card, from)
    if self.player.hp ~= self.player.maxHp then
      return -45
    end
  end,
  value = 1.5,
  priority = 4
}
fk.ai_card.amazing_grace = {
  intention = -30,
  value = 2,
  priority = 2
}
fk.ai_card.indulgence = {
  intention = 150,
  value = -1,
  priority = 2
}

local function slashEeffect(slash, to)
  for _, s in ipairs(to:getAllSkills()) do
    if s.name == "#vine_skill" then
      if slash.name == "slash" then
        return
      end
    end
    if s.name == "#nioh_shield_skill" then
      if slash.color == Card.Black then
        return
      end
    end
  end
  return true
end

fk.ai_use_play.slash = function(self, card)
  self:sort(self.enemies)
  for _, p in ipairs(self.enemies) do
    if card.skill:targetFilter(p.id, self.use_tos, {}, card) and slashEeffect(card, p) then
      self.use_id = card.id
      table.insert(self.use_tos, p.id)
    end
  end
end

fk.ai_askuse_card["#slash-jink"] = function(self, pattern, prompt, cancelable, extra_data)
  local act = self:getActives(pattern)
  if tonumber(prompt:split(":")[4]) > #act then
    return
  end
  local cards =
      table.map(
        self.player:getCardIds("&he"),
        function(id)
          return Fk:getCardById(id)
        end
      )
  self:sortValue(cards)
  for _, sth in ipairs(act) do
    if sth:isInstanceOf(Card) then
      self.use_id = sth.id
      break
    else
      local selected = {}
      for _, c in ipairs(cards) do
        if sth.cardFilter(sth, c.id, selected) then
          table.insert(selected, c.id)
        end
      end
      local tc = sth.viewAs(sth, selected)
      if tc and tc:matchPattern(pattern) then
        self.use_id =
            json.encode {
              skill = sth.name,
              subcards = selected
            }
        break
      end
    end
  end
end

fk.ai_askuse_card["#slash-jinks"] = fk.ai_askuse_card["#slash-jink"]

fk.ai_use_play.snatch = function(self, card)
  for _, p in ipairs(self.friends_noself) do
    if card.skill:targetFilter(p.id, self.use_tos, {}, card) and #p:getCardIds("j") > 0 then
      self.use_id = card.id
      table.insert(self.use_tos, p.id)
    end
  end
  self:sort(self.enemies)
  for _, p in ipairs(self.enemies) do
    if card.skill:targetFilter(p.id, self.use_tos, {}, card) and #p:getCardIds("he") > 0 then
      self.use_id = card.id
      table.insert(self.use_tos, p.id)
    end
  end
end

fk.ai_nullification.snatch = function(self, card, to, from, positive)
  if positive then
    if self:isFriend(to) and not self:isFriend(from) and fk.ai_role[from.id] ~= "neutral" then
      if #self.avail_cards > 1 or self:isWeak(to) or to.id == self.player.id then
        self.use_id = self.avail_cards[1]
      end
    end
  else
    if self:isEnemie(to) and self:isEnemie(from) then
      if #self.avail_cards > 1 or self:isWeak(to) then
        self.use_id = self.avail_cards[1]
      end
    end
  end
end

fk.ai_use_play.dismantlement = function(self, card)
  for _, p in ipairs(self.friends_noself) do
    if card.skill:targetFilter(p.id, self.use_tos, {}, card) and #p:getCardIds("j") > 0 then
      self.use_id = card.id
      table.insert(self.use_tos, p.id)
    end
  end
  self:sort(self.enemies)
  for _, p in ipairs(self.enemies) do
    if card.skill:targetFilter(p.id, self.use_tos, {}, card) and #p:getCardIds("he") > 0 then
      self.use_id = card.id
      table.insert(self.use_tos, p.id)
    end
  end
end

fk.ai_nullification.dismantlement = function(self, card, to, from, positive)
  if positive then
    if self:isFriend(to) and not self:isFriend(from) and fk.ai_role[from.id] ~= "neutral" then
      if #self.avail_cards > 1 or self:isWeak(to) or to.id == self.player.id then
        self.use_id = self.avail_cards[1]
      end
    end
  else
    if self:isEnemie(to) and self:isEnemie(from) then
      if #self.avail_cards > 1 or self:isWeak(to) then
        self.use_id = self.avail_cards[1]
      end
    end
  end
end

fk.ai_use_play.indulgence = function(self, card)
  self:sort(self.enemies, nil, true)
  for _, p in ipairs(self.enemies) do
    if card.skill:targetFilter(p.id, self.use_tos, {}, card) then
      self.use_id = card.id
      table.insert(self.use_tos, p.id)
    end
  end
end

fk.ai_nullification.indulgence = function(self, card, to, from, positive)
  if positive then
    if self:isFriend(to) then
      if #self.avail_cards > 1 or self:isWeak(to) or to.id == self.player.id then
        self.use_id = self.avail_cards[1]
      end
    end
  else
    if self:isEnemie(to) then
      if #self.avail_cards > 1 or self:isWeak(to) then
        self.use_id = self.avail_cards[1]
      end
    end
  end
end

fk.ai_use_play.collateral = function(self, card)
  local max = (card.skill:getMaxTargetNum(self.player, card) - 1) * 2
  self:sort(self.enemies)
  for _, p in ipairs(self.enemies) do
    if #self.use_tos < max and card.skill:targetFilter(p.id, {}, {}, card) then
      for _, pt in ipairs(self.enemies) do
        if p ~= pt and p:inMyAttackRange(pt) then
          table.insert(self.use_tos, p.id)
          table.insert(self.use_tos, pt.id)
          self.use_id = card.id
          break
        end
      end
    end
  end
  for _, p in ipairs(self.friends_noself) do
    if #self.use_tos < max and card.skill:targetFilter(p.id, {}, {}, card) then
      for _, pt in ipairs(self.enemies) do
        if p ~= pt and p:inMyAttackRange(pt) then
          table.insert(self.use_tos, p.id)
          table.insert(self.use_tos, pt.id)
          self.use_id = card.id
          break
        end
      end
    end
  end
end

fk.ai_nullification.collateral = function(self, card, to, from, positive)
  if positive then
    if self:isFriend(to) and self:isEnemie(from) then
      if #self.avail_cards > 1 or self:isWeak(to) or to.id == self.player.id then
        self.use_id = self.avail_cards[1]
      end
    end
  end
end

fk.ai_nullification.ex_nihilo = function(self, card, to, from, positive)
  if positive then
    if self:isEnemie(to) then
      if #self.avail_cards > 1 or self:isWeak(to) then
        self.use_id = self.avail_cards[1]
      end
    end
  else
    if self:isFriend(to) then
      if #self.avail_cards > 1 or self:isWeak(to) or to.id == self.player.id then
        self.use_id = self.avail_cards[1]
      end
    end
  end
end

fk.ai_nullification.savage_assault = function(self, card, to, from, positive)
  if positive then
    if self:isFriend(to) then
      if #self.avail_cards > 1 or self:isWeak(to) or to.id == self.player.id then
        self.use_id = self.avail_cards[1]
      end
    end
  else
    if self:isEnemie(to) then
      if #self.avail_cards > 1 or self:isWeak(to) then
        self.use_id = self.avail_cards[1]
      end
    end
  end
end

fk.ai_nullification.archery_attack = function(self, card, to, from, positive)
  if positive then
    if self:isFriend(to) then
      if #self.avail_cards > 1 or self:isWeak(to) or to.id == self.player.id then
        self.use_id = self.avail_cards[1]
      end
    end
  else
    if self:isEnemie(to) then
      if #self.avail_cards > 1 or self:isWeak(to) then
        self.use_id = self.avail_cards[1]
      end
    end
  end
end

fk.ai_nullification.god_salvation = function(self, card, to, from, positive)
  if positive then
    if self:isEnemie(to) and to.hp ~= to.maxHp then
      if #self.avail_cards > 1 or self:isWeak(to) then
        self.use_id = self.avail_cards[1]
      end
    end
  else
    if self:isFriend(to) and to.hp ~= to.maxHp then
      if #self.avail_cards > 1 or self:isWeak(to) or to.id == self.player.id then
        self.use_id = self.avail_cards[1]
      end
    end
  end
end

fk.ai_use_play.god_salvation = function(self, card)
  local can = 0
  for _, p in ipairs(self.enemies) do
    if p:isWounded()
    then
      can = can - 1
      if self:isWeak(p)
      then
        can = can - 1
      end
    end
  end
  for _, p in ipairs(self.friends) do
    if p:isWounded()
    then
      can = can + 1
      if self:isWeak(p)
      then
        can = can + 1
      end
    end
  end
  self.use_id = can > 0 and card.id
end

fk.ai_use_play.amazing_grace = function(self, card)
  self.use_id = #self.player:getCardIds("&h") <= self.player.hp and card.id
end

fk.ai_use_play.ex_nihilo = function(self, card)
  self.use_id = card.id
end

fk.ai_use_play.lightning = function(self, card)
  self.use_id = #self.enemies > #self.friends and card.id
end

fk.ai_use_play.peach = function(self, card)
  if self.command == "PlayCard" then
    self.use_id = self.player.hp ~= self.player.maxHp and self.player.hp < #self.player:getCardIds("h") and card.id
  else
    for _, p in ipairs(self.friends) do
      if p.dying then
        self.use_id = card.id
        self.use_tos = { p.id }
        break
      end
    end
  end
end

fk.ai_use_play.duel = function(self, card)
  self:sort(self.enemies)
  for _, p in ipairs(self.enemies) do
    if card.skill:targetFilter(p.id, self.use_tos, {}, card) then
      self.use_id = card.id
      table.insert(self.use_tos, p.id)
    end
  end
end

fk.ai_skill_invoke["#ice_sword_skill"] = function(self)
  local damage = self:eventData("Damage")
  return self:isFriend(damage.to) or not self:isWeak(damage.to) and #damage.to:getCardIds("e") > 1
end

fk.ai_skill_invoke["#double_swords_skill"] = function(self)
  local use = self:eventData("UseCard")
  for _, p in ipairs(TargetGroup:getRealTargets(use.tos)) do
    if not self:isFriend(p) and self.room:getPlayerById(p).gender ~= self.player.gender then
      return true
    end
  end
end

fk.ai_dis_card["#double_swords_skill"] = function(self, min_num, num, include_equip, cancelable, pattern, prompt)
  local use = self:eventData("UseCard")
  return self:isEnemie(use.from) and { self.player:getCardIds("h")[1] }
end

fk.ai_dis_card["#axe_skill"] = function(self, min_num, num, include_equip, cancelable, pattern, prompt)
  local ids = {}
  local effect = self:eventData("CardEffect")
  for _, cid in ipairs(self.player:getCardIds("he")) do
    if Fk:getCardById(cid):matchPattern(pattern) then
      table.insert(ids, cid)
    end
    if #ids >= min_num and self:isEnemie(effect.to)
    and (self:isWeak(effect.to) or #self.player:getCardIds("he") > 3) then
      return ids
    end
  end
end

fk.ai_skill_invoke["#kylin_bow_skill"] = function(self)
  local damage = self:eventData("Damage")
  return not self:isFriend(damage.to)
end

fk.ai_skill_invoke["#eight_diagram_skill"] = function(self)
  local effect = self:eventData("CardEffect")
  return effect and self:isFriend(effect.to)
end
