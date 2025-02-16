function SkillUseData:toLegacy()
  return {
    from = self.from.id,
    tos = table.map(self.tos, Util.IdMapper),
    cards = self.cards
  }
end

function SkillUseData:loadLegacy(spec)
  self.card = spec.cards
  self.from = Fk:currentRoom():getPlayerById(spec.from) --[[@as ServerPlayer]]
  self.tos = table.map(spec.tos, Util.Id2PlayerMapper)  --[[@as ServerPlayer[] ]]
end

--- 将新数据改为牢数据
function SkillEffectData:toLegacy()
  local ret = table.simpleClone(rawget(self, "_data"))
  if not ret.skill_data then return ret end
  ret.skill_data = SkillEffectData:_toLegacySkillData(ret.skill_data)
  return ret
end

--- 将牢数据改为新数据
function SkillEffectData:loadLegacy(data)
  if not data.skill_data then return end
  for k, v in pairs(data) do
    if k == "skill_data" then
      self[k] = SkillEffectData:_toLegacySkillData(v)
    else
      self[k] = v
    end
  end
end

--- 静态方法。
--- 将新数据改为牢数据（技能数据版）
function SkillEffectData:_toLegacySkillData(data)
  error("This is a static method. Please use SkillEffectData:_toLegacySkillData instead")
end

--- 静态方法。
--- 将牢数据改为新数据（技能数据版）
function SkillEffectData:_loadLegacySkillData(data)
  error("This is a static method. Please use SkillEffectData:_loadLegacySkillData instead")
end

function SkillEffectData.static:_toLegacySkillData(data)
  local ret = table.simpleClone(data)
  if data.from then
    ret.from = ret.from.id
  end
  if data.to then
    ret.to = ret.to.id
  end

  if data.tos and ((data.tos or {})[1] or {}).id then
    local new_v = {}
    for _, p in ipairs(data.tos) do
      table.insert(new_v, p.id)
    end
    ret.tos = new_v
  end
  return ret
end

--- 将牢数据改为新数据（技能数据版）
function SkillEffectData.static:_loadLegacySkillData(data)
  local ret = table.simpleClone(data)
  for k, v in pairs(data) do
    if table.contains({"from", "to"}, k) then
      ret[k] = Fk:currentRoom():getPlayerById(v)
    elseif table.contains({"nullifiedTargets", "disresponsiveList", "unoffsetableList"}, k) then
      local new_v = {}
      for _, pid in ipairs(v) do
        table.insert(new_v, Fk:currentRoom():getPlayerById(pid))
      end
      ret[k] = new_v
    elseif k == "tos" and type(v[1]) == "number" then
      local new_v = {}
      for _, pid in ipairs(v) do
        table.insert(new_v, Fk:currentRoom():getPlayerById(pid))
      end
      ret[k] = new_v
    else
      ret[k] = v
    end
  end
  return ret
end
