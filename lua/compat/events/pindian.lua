function PindianData:toLegacy()
  local ret = table.simpleClone(rawget(self, "_data"))

  if ret.results then
    local new_v = {}
    for sp, pv in pairs(ret.results) do
      new_v[sp.id] = pv
    end
    ret.results = new_v
  end
  return ret
end

--- 将牢数据改为新数据
function PindianData:loadLegacy(data)
  for k, v in pairs(data) do
    if table.contains({"results"}, k) then
      local new_v = {}
      for pid, pv in pairs(v) do
        new_v[Fk:currentRoom():getPlayerById(pid)] = pv
      end
      self[k] = new_v
    else
      self[k] = v
    end
  end
end
