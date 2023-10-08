-- SPDX-License-Identifier: GPL-3.0-or-later

---@class RandomAI: AI
local RandomAI = AI:subclass("RandomAI")

---@param self RandomAI
---@param skill ActiveSkill
---@param card Card | nil
local function useActiveSkill(self, skill, card)
  local room = self.room
  local player = self.player

  local filter_func = skill.cardFilter
  if card then
    filter_func = function() return false end
  end

  if self.command == "PlayCard" and (not skill:canUse(player, card) or player:prohibitUse(card)) then
    return ""
  end

  local max_try_times = 100
  local selected_targets = {}
  local selected_cards = {}
  local min = skill:getMinTargetNum()
  local max = skill:getMaxTargetNum(player, card)
  local min_card = skill:getMinCardNum()
  local max_card = skill:getMaxCardNum()
  for _ = 0, max_try_times do
    if skill:feasible(selected_targets, selected_cards, self.player, card) then break end
    local avail_targets = table.filter(self.room:getAlivePlayers(), function(p)
      local ret = skill:targetFilter(p.id, selected_targets, selected_cards, card or Fk:cloneCard'zixing')
      if ret and card then
        if player:prohibitUse(card) then
          ret = false
        end
      end
      return ret
    end)
    avail_targets = table.map(avail_targets, function(p) return p.id end)
    local avail_cards = table.filter(player:getCardIds{ Player.Hand, Player.Equip }, function(id)
      return filter_func(skill, id, selected_cards, selected_targets)
    end)

    if #avail_targets == 0 and #avail_cards == 0 then break end
    table.insertIfNeed(selected_targets, table.random(avail_targets))
    table.insertIfNeed(selected_cards, table.random(avail_cards))
  end
  if skill:feasible(selected_targets, selected_cards, self.player, card) then
    local ret = json.encode{
      card = card and card.id or json.encode{
        skill = skill.name,
        subcards = selected_cards,
      },
      targets = selected_targets,
    }
    -- print(ret)
    return ret
  end
  return ""
end

---@param self RandomAI
---@param skill ViewAsSkill
local function useVSSkill(self, skill, pattern, cancelable, extra_data)
  local player = self.player
  local room = self.room
  local precondition

  if self.command == "PlayCard" then
    precondition = skill:enabledAtPlay(player)
    if not precondition then return nil end
    local exp = Exppattern:Parse(skill.pattern)
    local cnames = {}
    for _, m in ipairs(exp.matchers) do
      if m.name then table.insertTable(cnames, m.name) end
    end
    for _, n in ipairs(cnames) do
      local c = Fk:cloneCard(n)
      precondition = c.skill:canUse(Self, c)
      if precondition then break end
    end
  else
    precondition = skill:enabledAtResponse(player)
    if not precondition then return nil end
    local exp = Exppattern:Parse(pattern)
    precondition = exp:matchExp(skill.pattern)
  end

  if (not precondition) or math.random() < 0.2 then return nil end

  local selected_cards = {}
  local max_try_time = 100

  for _ = 0, max_try_time do
    local avail_cards = table.filter(player:getCardIds{ Player.Hand, Player.Equip }, function(id)
      return skill:cardFilter(id, selected_cards)
    end)
    if #avail_cards == 0 then break end
    table.insert(selected_cards, table.random(avail_cards))
    if skill:viewAs(selected_cards) then
      return {
        skill = skill.name,
        subcards = selected_cards,
      }
    end
  end
  return nil
end

---@type table<string, fun(self: RandomAI, jsonData: string): string>
local random_cb = {}

random_cb["AskForUseActiveSkill"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local skill = Fk.skills[data[1]]
  local cancelable = data[3]
  if cancelable and math.random() < 0.25 then return "" end
  local extra_data = json.decode(data[4])
  for k, v in pairs(extra_data) do
    skill[k] = v
  end
  return useActiveSkill(self, skill)
end

random_cb["AskForSkillInvoke"] = function(self, jsonData)
  return table.random{"1", ""}
end

random_cb["AskForUseCard"] = function(self, jsonData)
  local player = self.player
  local data = json.decode(jsonData)
  local card_name = data[1]
  local pattern = data[2] or card_name
  local cancelable = data[4] or true
  local exp = Exppattern:Parse(pattern)

  local avail_cards = table.map(player:getCardIds("he"),
    function(id) return Fk:getCardById(id) end)
  avail_cards = table.filter(avail_cards, function(c)
    return exp:match(c) and not player:prohibitUse(c)
  end)
  if #avail_cards > 0 then
    if math.random() < 0.25 then return "" end
    for _, card in ipairs(avail_cards) do
      local skill = card.skill
      local max_try_times = 100
      local selected_targets = {}
      local min = skill:getMinTargetNum()
      local max = skill:getMaxTargetNum(player, card)
      local min_card = skill:getMinCardNum()
      local max_card = skill:getMaxCardNum()
      for _ = 0, max_try_times do
        if skill:feasible(selected_targets, { card.id }, self.player, card) then
          return json.encode{
            card = table.random(avail_cards).id,
            targets = selected_targets,
            }
        end
        local avail_targets = table.filter(self.room:getAlivePlayers(), function(p)
          return skill:targetFilter(p.id, selected_targets, {card.id}, card or Fk:cloneCard'zixing')
        end)
        avail_targets = table.map(avail_targets, function(p) return p.id end)

        if #avail_targets == 0 and #avail_cards == 0 then break end
        table.insertIfNeed(selected_targets, table.random(avail_targets))
      end
    end
  end
  return ""
end

random_cb["AskForResponseCard"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local pattern = data[2]
  local cancelable = true
  local exp = Exppattern:Parse(pattern)
  local avail_cards = table.filter(self.player:getCardIds{ Player.Hand, Player.Equip }, function(id)
    return exp:match(Fk:getCardById(id))
  end)
  if #avail_cards > 0 then return json.encode{
    card = table.random(avail_cards),
    targets = {},
  } end
  -- TODO: vs skill
  return ""
end

random_cb["PlayCard"] = function(self, jsonData)
  local cards = table.map(self.player:getCardIds(Player.Hand),
    function(id) return Fk:getCardById(id) end)
  local actives = table.filter(self.player:getAllSkills(), function(s)
    return s:isInstanceOf(ActiveSkill)
  end)
  local vss = table.filter(self.player:getAllSkills(), function(s)
    return s:isInstanceOf(ViewAsSkill)
  end)
  table.insertTable(cards, actives)
  table.insertTable(cards, vss)

  while #cards > 0 do
    local sth = table.random(cards)
    if sth:isInstanceOf(Card) then
      local card = sth
      local skill = card.skill ---@type ActiveSkill
      if math.random() > 0.15 then
        local ret = useActiveSkill(self, skill, card)
        if ret ~= "" then return ret end
        table.removeOne(cards, card)
      else
        table.removeOne(cards, card)
      end
    elseif sth:isInstanceOf(ActiveSkill) then
      local active = sth
      if math.random() > 0.30 then
        local ret = useActiveSkill(self, active, nil)
        if ret ~= "" then return ret end
      end
      table.removeOne(cards, active)
    else
      local vs = sth
      if math.random() > 0.20 then
        local ret = useVSSkill(self, vs)
        -- TODO: handle vs result
      end
      table.removeOne(cards, vs)
    end
  end

  return ""
end

function RandomAI:initialize(player)
  AI.initialize(self, player)
  self.cb_table = random_cb
end

return RandomAI
