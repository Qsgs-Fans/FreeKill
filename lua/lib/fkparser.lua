-- FreeKill's fkparse interface
-- fkparse (FreeKill parser), a game code generator
-- For license information, check generated lua files.

-- In most cases, fk's basic modules are loaded before extension calls
-- "require 'fkparser'", so we needn't to import lua modules here.

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

return fkp
