function DyingData:toLegacy()
  local ret = table.simpleClone(rawget(self, "_data"))
  ret.who = ret.who.id
  return ret
end

function DyingData:loadLegacy(spec)
end

function DeathData:toLegacy()
  local ret = table.simpleClone(rawget(self, "_data"))
  ret.who = ret.who.id
  return ret
end

function DeathData:loadLegacy(spec)
end
