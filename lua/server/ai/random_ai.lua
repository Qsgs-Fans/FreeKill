-- SPDX-License-Identifier: GPL-3.0-or-later

---@class RandomAI: AI
local RandomAI = AI:subclass("RandomAI")

---@param self RandomAI
---@param skill ActiveSkill
---@param card? Card
---@param extra_data? table
function RandomAI:useActiveSkill(skill, card, extra_data)
  local room = self.room
  local player = self.player
  extra_data = extra_data or Util.DummyTable

  if skill:isInstanceOf(ViewAsSkill) then return "" end

  if self.command == "PlayCard" and (not skill:canUse(player, card) or (card and player:prohibitUse(card))) then
    return ""
  end

  local interaction_data
  if skill and skill.interaction then
    skill.interaction.data = nil
    interaction_data = skill:interaction()
    if type(interaction_data) == "table" then
      if interaction_data.type == "spin" then
        interaction_data = math.random(interaction_data.from, interaction_data.to)
      elseif interaction_data.type == "combo" then
        interaction_data = interaction_data.default
      else
        -- use default data when handling custom interaction
        interaction_data = interaction_data.default or interaction_data.default_choice or nil
      end
    end
    if interaction_data == nil then return "" end
    skill.interaction.data = interaction_data
  end

  local max_try_times = 100
  local selected_targets = {}
  local selected_cards = {}

  -- TODO: ng that 'must_targets' & 'exclusive_targets' should be rebuilt later
  local limited_targets = {}
  for _, name in ipairs({"must_targets","exclusive_targets","include_targets"}) do
    if type(extra_data[name]) == "table" then
      table.insertTableIfNeed(limited_targets, extra_data[name])
    end
  end

  local all_cards = player:getCardIds{ Player.Hand, Player.Equip }
  if skill.expand_pile then
    if type(skill.expand_pile) == "string" then
      table.insertTableIfNeed(all_cards, player.special_cards[skill.expand_pile] or {})
    elseif type(skill.expand_pile) == "table" then
      table.insertTableIfNeed(all_cards, skill.expand_pile)
    end
  end

  --local max_target_num = skill:getMaxTargetNum(player, card)
  local card_filter_func = card and Util.FalseFunc or skill.cardFilter
  local firstTry
  for _ = 0, max_try_times do
    if not firstTry and skill:feasible(selected_targets, selected_cards, self.player, card) then
      firstTry = {table.simpleClone(selected_targets), table.simpleClone(selected_cards)}
    end
    if firstTry and math.random() < 0.1 then break end
    local avail_targets = table.filter(room.alive_players, function(p)
      return not table.contains(selected_targets, p.id) and (#limited_targets == 0 or table.contains(limited_targets, p.id))
      and skill:targetFilter(p.id, selected_targets, selected_cards, card)
      and (not card or not player:isProhibited(p, card))
    end)
    local avail_cards = table.filter(all_cards, function(id)
      return not table.contains(selected_cards, id) and card_filter_func(skill, id, selected_cards, selected_targets)
    end)
    local random_list = table.connect(avail_targets, avail_cards)
    if #random_list == 0 then break end
    local randomIndex = math.random(#random_list)
    if randomIndex <= #avail_targets then
      table.insertIfNeed(selected_targets, random_list[randomIndex].id)
    else
      table.insertIfNeed(selected_cards, random_list[randomIndex])
    end
  end
  local feasibleCheck = function () return skill:feasible(selected_targets, selected_cards, self.player, card) end
  if firstTry and not feasibleCheck() then
    selected_targets = firstTry[1]
    selected_cards = firstTry[2]
  end
  if feasibleCheck() then
    local ret = json.encode{
      card = card and card.id or json.encode{
        skill = skill.name,
        subcards = selected_cards,
      },
      targets = selected_targets,
      interaction_data = interaction_data,
    }
    return ret
  end
  return ""
end


---@param skill ViewAsSkill
---@param pattern? string @ no 'pattern' means it needs to pass the 'canUse' check
---@param cancelable? bool
---@param extra_data? table
---@param cardResponsing? bool
function RandomAI:useVSSkill(skill, pattern, cancelable, extra_data, cardResponsing)
  local player = self.player
  local room = self.room
  local precondition
  cancelable = cancelable or (cancelable == nil)
  extra_data = extra_data or Util.DummyTable
  if not skill then return "" end

  if not pattern then
    precondition = skill:enabledAtPlay(player)
    if not precondition then return "" end
    local exp = Exppattern:Parse(skill.pattern)
    local cnames = {}
    for _, m in ipairs(exp.matchers) do
      if m.name then table.insertTable(cnames, m.name) end
    end
    for _, n in ipairs(cnames) do
      local c = Fk:cloneCard(n)
      precondition = c.skill:canUse(player, c, extra_data)
      if precondition then break end
    end
  else
    precondition = skill:enabledAtResponse(player, cardResponsing) and Exppattern:Parse(pattern):matchExp(skill.pattern)
  end

  if (not precondition) or (cancelable and math.random() < 0.2) then return "" end

  local interaction_data
  if skill.interaction then
    skill.interaction.data = nil
    interaction_data = skill:interaction()
    if type(interaction_data) == "table" then
      if interaction_data.type == "spin" then
        interaction_data = math.random(interaction_data.from, interaction_data.to)
      elseif interaction_data.type == "combo" then
        interaction_data = interaction_data.default
      else
        -- use default data when handling custom interaction
        interaction_data = interaction_data.default or interaction_data.default_choice or nil
      end
    end
    if interaction_data == nil then return "" end
    skill.interaction.data = interaction_data
  end

  local selected_cards = {}
  local selected_targets = {}
  local card
  local max_try_time = 100
  local all_cards = player:getCardIds{ Player.Hand, Player.Equip }
  if skill.expand_pile then
    if type(skill.expand_pile) == "string" then
      table.insertTableIfNeed(all_cards, player.special_cards[skill.expand_pile] or {})
    elseif type(skill.expand_pile) == "table" then
      table.insertTableIfNeed(all_cards, skill.expand_pile)
    end
  end

  for _ = 0, max_try_time do
    card = skill:viewAs(selected_cards)
    if card then break end
    local avail_cards = table.filter(all_cards, function(id)
      return not table.contains(selected_cards, id) and skill:cardFilter(id, selected_cards)
    end)
    if #avail_cards == 0 then break end
    table.insert(selected_cards, table.random(avail_cards))
  end

  if not card then return "" end

  if cardResponsing then
    if not player:prohibitResponse(card) then
      return json.encode{
        card = json.encode{
          skill = skill.name,
          subcards = selected_cards,
        },
        targets = {},
        interaction_data = interaction_data,
      }
    end
    return ""
  end

  if player:prohibitUse(card) then return "" end

  if pattern or player:canUse(card, extra_data) then

    local limited_targets = {}
    for _, name in ipairs({"must_targets","exclusive_targets","include_targets"}) do
      if type(extra_data[name]) == "table" then
        table.insertTableIfNeed(limited_targets, extra_data[name])
      end
    end

    for _ = 0, max_try_time do
      if card.skill:feasible(selected_targets, selected_cards, player, card) then break end
      local avail_targets = table.filter(room.alive_players, function(p)
        return not table.contains(selected_targets, p.id) and (#limited_targets == 0 or table.contains(limited_targets, p.id))
        and card.skill:targetFilter(p.id, selected_targets, selected_cards, card, extra_data)
        and not player:isProhibited(p, card)
      end)
      if #avail_targets == 0 then break end
      table.insert(selected_targets, table.random(avail_targets).id)
    end
    if card.skill:feasible(selected_targets, selected_cards, player, card, extra_data) then
      local ret = json.encode{
        card = json.encode{
          skill = skill.name,
          subcards = selected_cards,
        },
        targets = selected_targets,
        interaction_data = interaction_data,
      }
      return ret
    end
  end

  return ""
end

---@type table<string, fun(self: RandomAI, jsonData: string): string>
local random_cb = {}

random_cb["AskForUseActiveSkill"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local skill = Fk.skills[data[1]]
  if not skill then return "" end
  local cancelable = data[3]
  if cancelable and math.random() < 0.25 then return "" end
  local extra_data = data[4]
  for k, v in pairs(extra_data) do
    skill[k] = v
  end
  if skill:isInstanceOf(ViewAsSkill) then
    return self:useVSSkill(skill, nil, cancelable, extra_data)
  end
  local player = self.player
  if skill.name == "choose_cards_skill" then
    local exp = Exppattern:Parse(extra_data.pattern)
    local cards = table.filter(player:getCardIds(extra_data.include_equip and "he" or "h"), function(cid)
      return exp:match(Fk:getCardById(cid))
    end)
    local maxNum = extra_data.num
    local minNum = extra_data.min_num
    cards = table.random(cards, math.random(minNum, maxNum))
    return json.encode{
      card = json.encode{
        skill = skill.name,
        subcards = cards,
      },
      targets = {},
    }
  end
  return self:useActiveSkill(skill)
end

random_cb["AskForSkillInvoke"] = function(self, jsonData)
  local skill_name, prompt = table.unpack(json.decode(jsonData))
  local chance = 0.55
  if Fk.skills[skill_name] ~= nil and self.player:hasSkill(skill_name) then
    chance = 0.8
  end
  if math.random() < chance then
    return "1"
  end
  return ""
end

random_cb["AskForChoice"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local choices = data[1]
  if table.contains(choices, "Cancel") and #choices > 1 and math.random() < 0.6 then
    table.removeOne(choices, "Cancel")
  end
  return table.random(choices)
end

random_cb["AskForUseCard"] = function(self, jsonData)
  local player = self.player
  local data = json.decode(jsonData)
  local card_name = data[1]
  local pattern = data[2] or card_name
  local prompt = data[3]
  local cancelable = data[4]
  local extra_data = data[5] or Util.DummyTable

  if card_name == "peach" then
    if type(extra_data.must_targets) == "table" and extra_data.must_targets[1] ~= player.id and math.random() < 0.8 then
      return ""
    end
  end

  if (cancelable and math.random() < 0.15) then return "" end

  local cards = table.map(self.player:getCardIds("he&"), Util.Id2CardMapper)
  local exp = Exppattern:Parse(pattern)
  cards = table.filter(cards, function(c)
    return exp:match(c) and not player:prohibitUse(c)
  end)
  local vss = table.filter(player:getAllSkills(), function(s)
    return s:isInstanceOf(ViewAsSkill)
  end)
  table.insertTable(cards, vss)

  while #cards > 0 do
    local sth = table.remove(cards, math.random(#cards))
    if sth:isInstanceOf(Card) then
      local ret = self:useActiveSkill(sth.skill, sth, extra_data)
      if ret ~= "" then return ret end
    else
      local ret = self:useVSSkill(sth, pattern, cancelable, extra_data)
      if ret ~= "" then return ret end
    end
  end

  return ""
end

random_cb["AskForResponseCard"] = function(self, jsonData)
  local data = json.decode(jsonData)
  local pattern = data[2]
  local cancelable = data[4] or true
  local extra_data = data[5] or Util.DummyTable
  local player = self.player

  local cards = table.map(self.player:getCardIds("he&"), Util.Id2CardMapper)
  local exp = Exppattern:Parse(pattern)
  cards = table.filter(cards, function(c)
    return exp:match(c) and not player:prohibitResponse(c)
  end)

  local vss = table.filter(player:getAllSkills(), function(s)
    return s:isInstanceOf(ViewAsSkill)
  end)
  table.insertTable(cards, vss)

  while #cards > 0 do
    local sth = table.remove(cards, math.random(#cards))
    if sth:isInstanceOf(Card) then
      return json.encode{ card = sth.id, targets = {} }
    else
      local ret = self:useVSSkill(sth, pattern, cancelable, extra_data, true)
      if ret ~= "" then return ret end
    end
  end
  return ""
end

random_cb["PlayCard"] = function(self, jsonData)
  local cards = table.map(self.player:getCardIds("h&"), Util.Id2CardMapper)
  local actives = table.filter(self.player:getAllSkills(), function(s)
    return s:isInstanceOf(ActiveSkill)
  end)
  local vss = table.filter(self.player:getAllSkills(), function(s)
    return s:isInstanceOf(ViewAsSkill)
  end)
  table.insertTable(cards, actives)
  table.insertTable(cards, vss)

  while #cards > 0 do
    local sth = table.remove(cards, math.random(#cards))
    if sth:isInstanceOf(Card) then
      local card = sth
      local skill = card.skill ---@type ActiveSkill
      if math.random() > 0.15 then
        local ret = RandomAI.useActiveSkill(self, skill, card)
        if ret ~= "" then return ret end
      end
    elseif sth:isInstanceOf(ActiveSkill) then
      local active = sth
      if math.random() > 0.30 then
        local ret = RandomAI.useActiveSkill(self, active, nil)
        if ret ~= "" then return ret end
      end
    else
      local vs = sth
      if math.random() > 0.20 then
        local ret = self:useVSSkill(vs)
        if ret ~= "" then return ret end
      end
    end
  end

  return ""
end

-- FIXME: for smart ai
RandomAI.cb_table = random_cb

function RandomAI:initialize(player)
  AI.initialize(self, player)
  self.cb_table = random_cb
end

return RandomAI
