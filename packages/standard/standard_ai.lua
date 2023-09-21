fk.ai_use_play.rende = function(self, skill)
  for _, p in ipairs(self.friends_noself) do
    if p.kingdom == "shu" and #self.player:getCardIds("h") >= self.player.hp then
      self.use_id = {}
      for _, cid in ipairs(self.player:getCardIds("h")) do
        if #self.use_id < #self.player:getCardIds("h") / 2 then
          table.insert(self.use_id, cid)
        end
      end
      self.use_tos = { p.id }
      return
    end
  end
  for _, p in ipairs(self.friends_noself) do
    if #self.player:getCardIds("h") >= self.player.hp then
      self.use_id = {}
      for _, cid in ipairs(self.player:getCardIds("h")) do
        if #self.use_id < #self.player:getCardIds("h") / 2 then
          table.insert(self.use_id, cid)
        end
      end
      self.use_tos = { p.id }
      return
    end
  end
end

fk.ai_card.jijiang = { priority = 10 }

fk.ai_use_play.lijian = function(self, skill)
  local c = Fk:cloneCard("duel")
  c.skillName = "lijian"
  for _, p in ipairs(self.enemies) do
    for _, pt in ipairs(self.enemies) do
      if p.gender == General.Male and pt.gender == General.Male and p.id ~= pt.id and
          c.skill:targetFilter(pt.id, {}, p.id, c) then
        self.use_id = { self.player:getCardIds("he")[1] }
        self.use_tos = { pt.id, p.id }
        break
      end
    end
  end
  for _, p in ipairs(self.friends_noself) do
    for _, pt in ipairs(self.enemies) do
      if p.gender == General.Male and pt.gender == General.Male and p.id ~= pt.id and
          c.skill:targetFilter(pt.id, {}, p.id, c) then
        self.use_id = { self.player:getCardIds("he")[1] }
        self.use_tos = { pt.id, p.id }
        break
      end
    end
  end
end

fk.ai_card.lijian = { priority = 2 }

fk.ai_use_play.zhiheng = function(self, skill)
  local card_ids = {}
  for _, h in ipairs(self.player:getCardIds("he")) do
    if #card_ids < #self.player:getCardIds("he") / 2 then
      table.insert(card_ids, h)
    end
  end
  if #card_ids > 0 then
    self.use_id = card_ids
  end
end

fk.ai_use_play.kurou = function(self, skill)
  if #self:getActives("peach") + self.player.hp > 1 then
    local slash = Fk:cloneCard("slash")
    if slash.skill:canUse(self.player, slash) and not self.player:prohibitUse(slash) then
      fk.ai_use_play.slash(self, slash)
      if self.use_id then
        self.use_id = {}
        self.use_tos = {}
      end
    end
  end
end

fk.ai_use_play.fanjian = function(self, skill)
  for _, p in ipairs(self.enemies) do
    if #self.player:getCardIds("h") > 0 then
      self.use_id = {}
      table.insert(self.use_tos, p.id)
      break
    end
  end
end

fk.ai_use_play.jieyin = function(self, skill)
  for cs, p in ipairs(self.friends_noself) do
    cs = self.player:getCardIds("h")
    if #cs > 1 and p.gender == General.Male and p:isWounded() then
      self.use_id = { cs[1], cs[2] }
      table.insert(self.use_tos, p.id)
      break
    end
  end
end

fk.ai_use_play.qingnang = function(self, skill)
  for cs, p in ipairs(self.friends) do
    cs = self.player:getCardIds("h")
    if #cs > 0 and p:isWounded() then
      self.use_id = { cs[1] }
      table.insert(self.use_tos, p.id)
      break
    end
  end
end

fk.ai_skill_invoke.jianxiong = true

fk.ai_card.hujia = { priority = 10 }

fk.ai_response_card["#hujia-ask"] = function(self, pattern, prompt, cancelable, data)
  local to = self.room:getPlayerById(tonumber(prompt:split(":")[2]))
  if to and self:isFriend(to) then
    self:setUseId(pattern)
  end
end

fk.ai_response_card["#jijiang-ask"] = fk.ai_response_card["#hujia-ask"]

fk.ai_skill_invoke.fankui = function(self, data, prompt)
  local damage = self:eventData("Damage")
  return damage and damage.from and not self:isFriend(damage.from)
end

fk.ai_response_card["#guicai-ask"] = function(self, pattern, prompt, cancelable, data)
  local cards = table.map(self.player:getHandlyIds(true), function(id)
    return Fk:getCardById(id)
  end)
  local id = self:getRetrialCardId(cards)
  if id then
    self.use_id = id
  end
end

fk.ai_skill_invoke.ganglie = function(self, data, prompt)
  local damage = self:eventData("Damage")
  return damage and damage.from and not self:isFriend(damage.from)
end

fk.ai_skill_invoke.luoyi = function(self, data, prompt)
  for _, p in ipairs(self.enemies) do
    if #self:getActives("slash") > 0 and not self:isWeak() then
      return true
    end
  end
end

fk.ai_skill_invoke.tiandu = true

fk.ai_skill_invoke.yiji = true

fk.ai_skill_invoke.luoshen = true

fk.ai_skill_invoke.guanxing = true

fk.ai_skill_invoke.tieqi = function(self, data, prompt)
  local use = self:eventData("UseCard")
  for _, p in ipairs(TargetGroup:getRealTargets(use.tos)) do
    p = self.room:getPlayerById(p)
    if self:isEnemie(p) then
      return true
    end
  end
end

fk.ai_skill_invoke.jizhi = true

fk.ai_skill_invoke.keji = true

fk.ai_skill_invoke.yingzi = true

fk.ai_skill_invoke.lianying = true

fk.ai_skill_invoke.xiaoji = true

fk.ai_skill_invoke.biyue = true

fk.ai_choose_players.tuxi = function(self, targets, min_num, num, cancelable)
  for _, pid in ipairs(targets) do
    local p = self.room:getPlayerById(pid)
    if self:isEnemie(p) and #self.use_tos < num then
      table.insert(self.use_tos, pid)
    end
  end
end

fk.ai_use_skill.yiji_active = function(self, prompt, cancelable, data)
  for _, p in ipairs(self.friends_noself) do
    for c, cid in ipairs(self.player.yiji_ids) do
      c = Fk:getCardById(cid)
      if c:getMark("yiji") > 0 and c.skill:canUse(p, c) then
        self.use_tos = { p.id }
        self.use_id = json.encode {
          skill = "yiji_active",
          subcards = { cid }
        }
        return
      end
    end
  end
end

fk.ai_choose_players.liuli = function(self, targets, min_num, num, cancelable)
  for _, pid in ipairs(targets) do
    local p = self.room:getPlayerById(pid)
    if self:isEnemie(p) and #self.use_tos < num and #self.player:getCardIds("he") > 0 then
      table.insert(self.use_tos, pid)
      self.use_id = { self.player:getCardIds("he")[1] }
      return
    end
  end
  for _, pid in ipairs(targets) do
    local p = self.room:getPlayerById(pid)
    if not self:isFriend(p) and #self.use_tos < num and #self.player:getCardIds("he") > 0 then
      table.insert(self.use_tos, pid)
      self.use_id = { self.player:getCardIds("he")[1] }
      return
    end
  end
end
