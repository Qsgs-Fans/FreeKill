-- FreeKill's fkparse interface
-- fkparse (FreeKill parser), a game code generator
-- For license information, check generated lua files.

-- In most cases, fk's basic modules are loaded before extension calls
-- "require 'fkparser'", so we needn't to import lua modules here.

local string2suit = {
  spade = Card.Spade,
  club = Card.Club,
  heart = Card.Heart,
  diamond = Card.Diamond,
  no_suit = Card.NoSuit,
  no_suit_black = Card.NoSuitBlack,
  no_suit_red = Card.NoSuitRed,
}

local fkp = { functions = {} }

fkp.functions.prepend = function(arr, e) table.insert(arr, 1, e) end
fkp.functions.append = function(arr, e) table.insert(arr, e) end
fkp.functions.drawCards = function(p, n) p:drawCards(n) end
fkp.functions.loseHp = function(p, n) p.room:loseHp(p, n) end
fkp.functions.loseMaxHp = function(p, n) p.room:changeMaxHp(p, -n) end
fkp.functions.damage = function(from, to, n, nature, card, reason)
  local damage = {}
  damage.from = from
  damage.to = to
  damage.damage = n
  damage.damageType = nature
  damage.card = card
  damage.skillName = reason
  to.room:damage(damage)
end

fkp.functions.recover = function(player, int, who, card)
  local recover = {}
  recover.who = player
  recover.num = int
  recover.recoverBy = who
  recover.card = card
  player.room:recover(recover)
end

fkp.functions.recoverMaxHp = function(p, n) p.room:changeMaxHp(p, n) end
fkp.functions.acquireSkill = function(player, skill)
  player.room:handleAddLoseSkills(player, skill)
end

fkp.functions.loseSkill = function(player, skill)
  player.room:handleAddLoseSkills(player, "-" .. skill)
end

fkp.functions.addMark = function(player, mark, count, hidden)
  local room = player.room
  if hidden then
    mark = string.gsub(mark, "@", "_")
  end

  room:addPlayerMark(player, mark, count)
end

fkp.functions.loseMark = function(player, mark, count, hidden)
  local room = player.room
  if hidden then
    mark = string.gsub(mark, "@", "_")
  end

  room:removePlayerMark(player, mark, count)
end

fkp.functions.getMark = function(player, mark, hidden)
  if hidden then
    mark = string.gsub(mark, "@", "_")
  end

  return player:getMark(mark)
end

fkp.functions.judge = function(player, reason, pattern, good, play_animation)
  local judge = {}
  judge.who = player
  judge.reason = reason
  judge.pattern = pattern
  -- judge.good = good
  -- judge.play_animation = play_animation
  player.room:judge(judge)
  return judge.card
end

fkp.functions.retrial = function(card, player, judge, skill_name, exchange)
  local room = player.room
  return room:retrial(card, player, judge, skill_name, exchange)
end

fkp.functions.hasSkill = function(p, s) return p:hasSkill(s) end
fkp.functions.turnOver = function(p) p:turnOver() end
fkp.functions.distanceTo = function(p1, p2) return p1:distanceTo(p2) end
fkp.functions.getCards = function(p, area)
  return table.map(p:getCardIds(area), function(id) return Fk:getCardById(id) end)
end

-- interactive methods

fkp.functions.buildPrompt = function(base, src, dest, arg, arg2)
  if src == nil then
    src = ""
  else
    src = src.id
  end
  if dest == nil then
    dest = ""
  else
    dest = dest.id
  end
  if arg == nil then arg = "" end
  if arg2 == nil then arg2 = "" end

  local prompt_tab = {src, dest, arg, arg2}
  if arg2 == "" then
    table.remove(prompt_tab, 4)
    if arg == "" then
      table.remove(prompt_tab, 3)
      if dest == "" then
        table.remove(prompt_tab, 2)
        if src == "" then
          table.remove(prompt_tab, 1)
        end
      end
    end
  end

  for _, str in ipairs(prompt_tab) do
    base = base .. ":" .. str
  end

  return base
end

fkp.functions.askForChoice = function(player, choices, reason)
  return player.room:askForChoice(player, choices, reason)
end

fkp.functions.askForPlayerChosen = function(player, targets, reason, prompt, optional, notify)
  return player.room:askForChoosePlayers(player, targets, 1, 1, prompt, reason)
end

fkp.functions.askForSkillInvoke = function(player, skill)
  return player:askForSkillInvoke(skill)
end

fkp.functions.askRespondForCard = function(player, pattern, prompt, isRetrial, skill_name)
  return player.room:askForResponse(player, skill_name, pattern, prompt, true)
end

-- skill prototypes
--------------------------------------------

fkp.CreateTriggerSkill = function(spec)
  local eve = {}
  local refresh_eve = {}
  local specs = spec.specs
  local re_specs = spec.refresh_specs
  for event, _ in pairs(specs) do
    table.insert(eve, event)
  end
  for event, _ in pairs(re_specs) do
    table.insert(refresh_eve, event)
  end
  return fk.CreateTriggerSkill{
    name = spec.name,
    frequency = spec.frequency or Skill.NotFrequent,
    events = eve,
    can_trigger = function(self, event, target, player, data)
      local func = specs[event] and specs[event][1] or nil
      if not func then
        return TriggerSkill.triggerable(self, event, target, player, data)
      end
      return func(self, target, player, data)
    end,
    on_trigger = function(self, event, target, player, data)
      local func = specs[event] and specs[event][4] or nil
      if not func then
        return TriggerSkill.trigger(self, event, target, player, data)
      end
      return func(self, target, player, data)
    end,
    on_cost = function(self, event, target, player, data)
      local func = specs[event] and specs[event][3] or nil
      if not func then
        return TriggerSkill.cost(self, event, target, player, data)
      end
      return func(self, target, player, data)
    end,
    on_use = function(self, event, target, player, data)
      local func = specs[event] and specs[event][2] or nil
      if not func then
        return TriggerSkill.use(self, event, target, player, data)
      end
      return func(self, target, player, data)
    end,

    refresh_events = refresh_eve,
    can_refresh = function(self, event, target, player, data)
      local func = re_specs[event] and re_specs[event][1] or nil
      if not func then
        return TriggerSkill.canRefresh(self, event, target, player, data)
      end
      return func(self, target, player, data)
    end,
    on_refresh = function(self, event, target, player, data)
      local func = re_specs[event] and re_specs[event][2] or nil
      if not func then
        return TriggerSkill.refresh(self, event, target, player, data)
      end
      return func(self, target, player, data)
    end,
  }
end

fkp.CreateActiveSkill = function(spec)
  return fk.CreateActiveSkill{
    name = spec.name,
    can_use = spec.can_use,
    card_filter = function(self, to_select, selected)
      local card = Fk:getCardById(to_select)
      local clist = {}
      for _, id in ipairs(selected) do
        table.insert(clist, Fk:getCardById(id))
      end
      return spec.card_filter(self, clist, card)
    end,
    target_filter = function(self, to_select, selected, cards)
      local room = Fk:currentRoom()
      local target = room:getPlayerById(to_select)
      local plist = {}
      for _, id in ipairs(selected) do
        table.insert(plist, room:getPlayerById(id))
      end
      local clist = {}
      for _, id in ipairs(cards) do
        table.insert(clist, Fk:getCardById(id))
      end
      return spec.target_filter(self, plist, target, clist)
    end,
    feasible = function(self, targets, cards)
      local room = Fk:currentRoom()
      local plist = {}
      for _, id in ipairs(targets) do
        table.insert(plist, room:getPlayerById(id))
      end
      local clist = {}
      for _, id in ipairs(cards) do
        table.insert(clist, Fk:getCardById(id))
      end
      return spec.feasible(self, plist, clist)
    end,
    on_use = function(self, room, use)
      local cards = use.cards
      local from = use.from
      local targets = use.tos
      local source = room:getPlayerById(from)
      local plist = {}
      for _, id in ipairs(targets) do
        table.insert(plist, room:getPlayerById(id))
      end
      local clist = {}
      for _, id in ipairs(cards) do
        table.insert(clist, Fk:getCardById(id))
      end
      return spec.on_use(self, source, plist, clist)
    end,
    on_effect = function(self, room, effect)
      -- TODO: active skill for card!
    end,
  }
end

fkp.functions.newVirtualCard = function(number, suit, name, subcards, skill)
  subcards = subcards or Util.DummyTable
  local ret = Fk:cloneCard(name, string2suit[suit], number)
  if not ret then
    ret = Fk:cloneCard("slash", string2suit[suit], number)
  end
  ret.skillName = skill
  ret:addSubcards(subcards)
  return ret
end

fkp.functions.buildPattern = function(names, suits, numbers)
  if not names then names = {"."} end
  if not suits then suits = {"."} end
  if not numbers then numbers = {"."} end

  names = table.concat(names, ",")
  suits = table.concat(suits, ",")
  numbers = table.concat(numbers, ",")
  return string.format("%s|%s|%s", names, numbers, suits)
end

fkp.CreateViewAsSkill = function(spec)
  return fk.CreateViewAsSkill{
    name = spec.name,
    card_filter = function(self, to_select, selected)
      local card = Fk:getCardById(to_select)
      local clist = {}
      for _, id in ipairs(selected) do
        table.insert(clist, Fk:getCardById(id))
      end
      return spec.card_filter(self, clist, card)
    end,
    view_as = function(self, cards)
      local clist = {}
      for _, c in ipairs(cards) do
        table.insert(clist, Fk:getCardById(c))
      end
      if spec.feasible(self, clist) then
        return spec.view_as(self, clist)
      end
      return nil
    end,
    enabled_at_play = spec.can_use,
    enabled_at_response = spec.can_response,
    pattern = table.concat(spec.response_patterns, ";"),
  }
end

fkp.CreateTargetModSkill = function(_spec)
  local spec = { name = _spec.name }
  local function getVCardFromActiveSkill(skill)
    if not string.find(skill.name, "_skill") then return 0 end
    local str = string.gsub(skill.name, "_skill", "")
    return Fk:cloneCard(str)
  end
  if _spec.residue_func then
    spec.residue_func = function(self, target, skill, scope, card)
      return _spec.residue_func(self, target, card or getVCardFromActiveSkill(skill))
    end
  end
  if _spec.distance_limit_func then
    spec.distance_limit_func = function(self, target, skill, card)
      return _spec.distance_limit_func(self, target, card or getVCardFromActiveSkill(skill))
    end
  end
  if _spec.extra_target_func then
    spec.extra_target_func = function(self, target, skill, card)
      return _spec.extra_target_func(self, target, card or getVCardFromActiveSkill(skill))
    end
  end
  return fk.CreateTargetModSkill(spec)
end

fkp.CreateFilterSkill = fk.CreateFilterSkill
fkp.CreateProhibitSkill = fk.CreateProhibitSkill
fkp.CreateDistanceSkill = fk.CreateDistanceSkill
fkp.CreateMaxCardsSkill = fk.CreateMaxCardsSkill
fkp.CreateAttackRangeSkill = fk.CreateAttackRangeSkill

return fkp
