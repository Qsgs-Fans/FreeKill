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

return fkp
