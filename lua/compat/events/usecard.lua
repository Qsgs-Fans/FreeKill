--- 将新数据改为牢数据
function RespondCardData:toLegacy()
  local ret = table.simpleClone(rawget(self, "_data"))
  for _, k in ipairs({"from", "customFrom"}) do
    local v = ret[k]
    if v then
      ret[k] = v.id
    end
  end
  return ret
end

--- 将牢数据改为新数据
function RespondCardData:loadLegacy(data)
  for k, v in pairs(data) do
    if table.contains({"from", "customFrom"}, k) then
      self[k] = Fk:currentRoom():getPlayerById(v)
    else
      self[k] = v
    end
  end
end

--- 将新数据改为牢数据
function UseCardData:toLegacy()
  local ret = table.simpleClone(rawget(self, "_data"))
  ret.from = ret.from and ret.from.id

  -- 傻逼tos可能nil
  if self.tos then
    local tos = {}
    for i, p in ipairs(self.tos) do
      local t = { p.id }
      local sub = self:getSubTos(p)
      if sub then
        table.insertTable(sub, table.map(sub, Util.IdMapper))
      end
      table.insert(tos, t)
    end
    ret.tos = tos
  end

  for _, k in ipairs({"nullifiedTargets", "disresponsiveList"}) do
    ret[k] = ret[k] and table.map(ret[k], Util.IdMapper)
  end

  if ret.damageDealt then
    local new_v = {}
    for sp, pv in pairs(ret.damageDealt) do
      new_v[sp.id] = pv
    end
    ret.damageDealt = new_v
  end

  return ret
end

--- 将牢数据改为新数据
function UseCardData:loadLegacy(data)
  for k, v in pairs(data) do
    if table.contains({"from"}, k) then
      if type(v) == "number" then
        self[k] = Fk:currentRoom():getPlayerById(v)
      else
        self[k] = v
      end
    elseif table.contains({"nullifiedTargets", "disresponsiveList"}, k) then
      self[k] = table.map(v, Util.Id2PlayerMapper)
    elseif table.contains({"damageDealt"}, k) then
      local new_v = {}
      for pid, pv in pairs(v) do
        new_v[Fk:currentRoom():getPlayerById(pid)] = pv
      end
      self[k] = new_v
    elseif k == "tos" then
      local targets = {}
      local subTargets = {}
      for _, grp in ipairs(v) do
        local sub = table.map(grp, Util.Id2PlayerMapper)
        local p = table.remove(sub, 1)
        table.insert(targets, p)
        table.insert(subTargets, sub)
      end
      self.tos = targets
      self.subTos = subTargets
    else
      self[k] = v
    end
  end
end

function AimData:toLegacy()
  local ret = table.simpleClone(rawget(self, "_data"))
  ret.from = ret.from and ret.from.id
  ret.to = ret.to and ret.to.id

  -- 傻逼tos可能nil
  if self.useTos then
    local tos = {}
    for i, p in ipairs(self.useTos) do
      local t = { p.id }
      local sub = self.useSubTos[i]
      if sub then
        table.insertTable(sub, table.map(sub, Util.IdMapper))
      end
      table.insert(tos, t)
    end
    ret.targetGroup = tos
  end

  ret.tos = {}
  for _, d in ipairs(self.tos) do
    table.insert(ret.tos, table.map(d, Util.IdMapper))
  end

  for _, k in ipairs({"nullifiedTargets", "disresponsiveList", "subTargets"}) do
    ret[k] = ret[k] and table.map(ret[k], Util.IdMapper)
  end

  return ret
end

function AimData:loadLegacy(data)
  for k, v in pairs(data) do
    if table.contains({"from", "to"}, k) then
      self[k] = Fk:currentRoom():getPlayerById(v)
    elseif table.contains({"nullifiedTargets", "disresponsiveList", "subTargets"}, k) then
      self[k] = table.map(v, Util.Id2PlayerMapper)
    elseif k == "targetGroup" then
      local targets = {}
      local subTargets = {}
      for _, grp in ipairs(v) do
        local sub = table.map(grp, Util.Id2PlayerMapper)
        local p = table.remove(sub, 1)
        table.insert(targets, p)
        table.insert(subTargets, sub)
      end
      self.useTos = targets
      self.useSubTos = subTargets
    elseif k == "tos" then
      self.tos = {}
      for _, d in ipairs(v) do
        table.insert(self.tos, table.map(d, Util.Id2PlayerMapper))
      end
    else
      self[k] = v
    end
  end
end

--- 将新数据改为牢数据
function CardEffectData:toLegacy()
  local ret = table.simpleClone(rawget(self, "_data"))
  ret.from = ret.from and ret.from.id
  ret.to = ret.to and ret.to.id

  -- 傻逼tos可能nil
  if self.tos then
    local tos = {}
    for i, p in ipairs(self.tos) do
      local t = { p.id }
      local sub = self:getSubTos(p)
      if sub then
        table.insertTable(sub, table.map(sub, Util.IdMapper))
      end
      table.insert(tos, t)
    end
    ret.tos = tos
  end

  for _, k in ipairs({"nullifiedTargets", "disresponsiveList", "unoffsetableList"}) do
    local v = ret[k]
    if v then
      local new_v = {}
      for _, p in ipairs(v) do
        table.insert(new_v, p.id)
      end
      ret[k] = new_v
    end
  end

  return ret
end

--- 将牢数据改为新数据
function CardEffectData:loadLegacy(data)
  for k, v in pairs(data) do
    if table.contains({"from", "to", "customFrom"}, k) then
      self[k] = Fk:currentRoom():getPlayerById(v)
    elseif table.contains({"nullifiedTargets", "disresponsiveList", "unoffsetableList"}, k) then
      local new_v = {}
      for _, pid in ipairs(v) do
        table.insert(new_v, Fk:currentRoom():getPlayerById(pid))
      end
      self[k] = new_v
    elseif k == "tos" then
      local targets = {}
      local subTargets = {}
      for _, grp in ipairs(v) do
        local sub = table.map(grp, Util.Id2PlayerMapper)
        local p = table.remove(sub, 1)
        table.insert(targets, p)
        table.insert(subTargets, sub)
      end
      self.tos = targets
      self.subTos = subTargets
    else
      self[k] = v
    end
  end
end
