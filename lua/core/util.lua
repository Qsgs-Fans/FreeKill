-- the iterator of QList object
local qlist_iterator = function(list, n)
  if n < list:length() - 1 then
    return n + 1, list:at(n + 1) -- the next element of list
  end
end

function fk.qlist(list)
  return qlist_iterator, list, -1
end

function table:contains(element)
  if #self == 0 or type(self[1]) ~= type(element) then return false end
  for _, e in ipairs(self) do
    if e == element then return true end
  end
end

function table:shuffle()
  for i = #self, 2, -1 do
      local j = math.random(i)
      self[i], self[j] = self[j], self[i]
  end
end

function table:insertTable(list)
  for _, e in ipairs(list) do
    table.insert(self, e)
  end
end

function table:indexOf(value, from)
  from = from or 1
  for i = from, #self do
    if self[i] == value then return i end
  end
  return -1
end

function table:removeOne(element)
  if #self == 0 or type(self[1]) ~= type(element) then return false end

  for i = 1, #self do
    if self[i] == element then
      table.remove(self, i)
      return true
    end
  end
  return false
end

-- Note: only clone key and value, no metatable
-- so dont use for class or instance
---@generic T
---@param self T
---@return T
function table.clone(self)
  local ret = {}
  for k, v in pairs(self) do
    if type(v) == "table" then
      ret[k] = table.clone(v)
    else
      ret[k] = v
    end
  end
  return ret
end

function table:insertIfNeed(element)
  if not table.contains(self, element) then
    table.insert(self, element)
  end
end

---@param delimiter string
---@return string[]
function string:split(delimiter)
  if #self == 0 then return {} end
  local result = {}
  local from = 1
  local delim_from, delim_to = string.find(self, delimiter, from)
  while delim_from do
    table.insert(result, string.sub(self, from, delim_from - 1))
    from  = delim_to + 1
    delim_from, delim_to = string.find(self, delimiter, from)
  end
  table.insert(result, string.sub(self, from))
  return result
end

---@class Sql
Sql = {
  ---@param filename string
  open = function(filename)
    return fk.OpenDatabase(filename)
  end,

  ---@param db fk.SQLite3
  close = function(db)
    fk.CloseDatabase(db)
  end,

  --- Execute an SQL statement.
  ---@param db fk.SQLite3
  ---@param sql string
  exec = function(db, sql)
    fk.ExecSQL(db, sql)
  end,

  --- Execute a `SELECT` SQL statement.
  ---@param db fk.SQLite3
  ---@param sql string
  ---@return table @ { [columnName] --> result : string[] }
  exec_select = function(db, sql)
    return json.decode(fk.SelectFromDb(db, sql))
  end,
}

FileIO = {
  pwd = fk.QmlBackend_pwd,
  ls = function(filename)
    if filename == nil then
      return fk.QmlBackend_ls(".")
    else
      return fk.QmlBackend_ls(filename)
    end
  end,
  cd = fk.QmlBackend_cd,
  exists = fk.QmlBackend_exists,
  isDir = fk.QmlBackend_isDir
}

os.getms = fk.GetMicroSecond

---@class Stack : Object
Stack = class("Stack")
function Stack:initialize()
  self.t = {}
  self.p = 0
end

function Stack:push(e)
  self.p = self.p + 1
  self.t[self.p] = e
end

function Stack:isEmpty()
  return self.p == 0
end

function Stack:pop()
  if self.p == 0 then return nil end
  self.p = self.p - 1
  return self.t[self.p + 1]
end


--- useful function to create enums
---
--- only use it in a terminal
---@param table string
---@param enum string[]
function CreateEnum(table, enum)
  local enum_format = "%s.%s = %d"
  for i, v in ipairs(enum) do
    print(string.format(enum_format, table, v, i))
  end
end

function switch(param, case_table)
  local case = case_table[param]
  if case then return case() end
  local def = case_table["default"]
  return def and def() or nil
end

---@class TargetGroup : Object
local TargetGroup = class("TargetGroup")

function TargetGroup.static:getRealTargets(targetGroup)
  if not targetGroup then
    return {}
  end

  local realTargets = {}
  for _, targets in ipairs(targetGroup) do
    table.insert(realTargets, targets[1])
  end

  return realTargets
end

function TargetGroup.static:includeRealTargets(targetGroup, playerId)
  if not targetGroup then
    return false
  end

  for _, targets in ipairs(targetGroup) do
    if targets[1] == playerId then
      return true
    end
  end

  return false
end

function TargetGroup.static:removeTarget(targetGroup, playerId)
  if not targetGroup then
    return
  end

  for index, targets in ipairs(targetGroup) do
    if (targets[1] == playerId) then
      table.remove(targetGroup, index)
      return
    end
  end
end

function TargetGroup.static:pushTargets(targetGroup, playerIds)
  if not targetGroup then
    return
  end

  if type(playerIds) == "table" then
    table.insert(targetGroup, playerIds)
  elseif type(playerIds) == "number" then
    table.insert(targetGroup, { playerIds })
  end
end

---@class AimGroup : Object
local AimGroup = class("AimGroup")

AimGroup.Undone = 1
AimGroup.Done = 2
AimGroup.Cancelled = 3

function AimGroup.static:initAimGroup(playerIds)
  return { [AimGroup.Undone] = playerIds, [AimGroup.Done] = {}, [AimGroup.Cancelled] = {} }
end

function AimGroup.static:getAllTargets(aimGroup)
  local targets = {}
  table.insertTable(targets, aimGroup[AimGroup.Undone])
  table.insertTable(targets, aimGroup[AimGroup.Done])
  return targets
end

function AimGroup.static:getUndoneOrDoneTargets(aimGroup, done)
  return done and aimGroup[AimGroup.Done] or aimGroup[AimGroup.Undone]
end

function AimGroup.static:setTargetDone(aimGroup, playerId)
  local index = table.indexOf(aimGroup[AimGroup.Undone], playerId)
  if index ~= -1 then
    table.remove(aimGroup[AimGroup.Undone], index)
    table.insert(aimGroup[AimGroup.Done], playerId)
  end
end

function AimGroup.static:addTargets(room, aimEvent, playerIds)
  local playerId = type(playerIds) == "table" and playerIds[1] or playerIds
  table.insert(aimEvent.tos[AimGroup.Undone], playerId)
  room:sortPlayersByAction(aimEvent.tos[AimGroup.Undone])
  if aimEvent.targetGroup then
    TargetGroup:pushTargets(aimEvent.targetGroup, playerIds)
  end
end

function AimGroup.static:cancelTarget(aimEvent, playerId)
  local cancelled = false
  for status = AimGroup.Undone, AimGroup.Done do
    local indexList = {}
    for index, pId in ipairs(aimEvent.tos[status]) do
      if pId == playerId then
        table.insert(indexList, index)
      end
    end

    if #indexList > 0 then
      cancelled = true
      for i = 1, #indexList do
        table.remove(aimEvent.tos[status], indexList[i])
      end
    end
  end

  if cancelled then
    table.insert(aimEvent.tos[AimGroup.Cancelled], playerId)
    if aimEvent.targetGroup then
      TargetGroup:removeTarget(aimEvent.targetGroup, playerId)
    end
  end
end

function AimGroup.static:removeDeadTargets(room, aimEvent)
  for index = AimGroup.Undone, AimGroup.Done do
    aimEvent.tos[index] = room:deadPlayerFilter(aimEvent.tos[index])
  end

  if aimEvent.targetGroup then
    local targets = TargetGroup:getRealTargets(aimEvent.targetGroup)
    for _, target in ipairs(targets) do
      if not room:getPlayerById(target):isAlive() then
        TargetGroup:removeTarget(aimEvent.targetGroup, target)
      end
    end
  end
end

function AimGroup.static:getCancelledTargets(aimGroup)
  return aimGroup[AimGroup.Cancelled]
end

return { TargetGroup, AimGroup }
