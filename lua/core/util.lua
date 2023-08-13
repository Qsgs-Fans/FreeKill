-- SPDX-License-Identifier: GPL-3.0-or-later

local Util = {}
Util.DummyFunc = function() end
Util.TrueFunc = function() return true end
Util.FalseFunc = function() return false end
Util.DummyTable = setmetatable({}, {
  __newindex = function() error("Cannot assign to dummy table") end
})

local metamethods = {
  "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__idiv",
  "__band", "__bor", "__bxor", "__bnot", "__shl", "__shr",
  "__concat", "__len", "__eq", "__lt", "__le", "__call",
  -- "__index", "__newindex",
}
-- 别对类用 暂且会弄坏isSubclassOf 懒得研究先
Util.lockTable = function(t)
  local mt = getmetatable(t) or Util.DummyTable
  local new_mt = {
    __index = t,
    __newindex = function() error("Cannot assign to locked table") end,
    __metatable = false,
  }
  for _, e in ipairs(metamethods) do
    new_mt[e] = mt[e]
  end
  return setmetatable({}, new_mt)
end

Util.convertSubtypeAndEquipSlot = function(value)
  if type(value) == "number" then
    local mapper = {
      [Card.SubtypeWeapon] = Player.WeaponSlot,
      [Card.SubtypeArmor] = Player.ArmorSlot,
      [Card.SubtypeOffensiveRide] = Player.OffensiveRideSlot,
      [Card.SubtypeDefensiveRide] = Player.DefensiveRideSlot,
      [Card.SubtypeTreasure] = Player.TreasureSlot,
    }

    return mapper[value]
  else
    local mapper = {
      [Player.WeaponSlot] = Card.SubtypeWeapon,
      [Player.ArmorSlot] = Card.SubtypeArmor,
      [Player.OffensiveRideSlot] = Card.SubtypeOffensiveRide,
      [Player.DefensiveRideSlot] = Card.SubtypeDefensiveRide,
      [Player.TreasureSlot] = Card.SubtypeTreasure,
    }

    return mapper[value]
  end
end

function printf(fmt, ...)
  print(string.format(fmt, ...))
end

-- the iterator of QList object
local qlist_iterator = function(list, n)
  if n < list:length() - 1 then
    return n + 1, list:at(n + 1) -- the next element of list
  end
end

function fk.qlist(list)
  return qlist_iterator, list, -1
end

---@param func fun(element, index, array)
function table:forEach(func)
  for i, v in ipairs(self) do
    func(v, i, self)
  end
end

---@param func fun(element, index, array): any
function table:every(func)
  for i, v in ipairs(self) do
    if not func(v, i, self) then
      return false
    end
  end
  return true
end

---@param func fun(element, index, array): any
function table:find(func)
  for i, v in ipairs(self) do
    if func(v, i, self) then
      return v
    end
  end
  return nil
end

---@generic T
---@param self T[]
---@param func fun(element, index, array): any
---@return T[]
function table.filter(self, func)
  local ret = {}
  for i, v in ipairs(self) do
    if func(v, i, self) then
      table.insert(ret, v)
    end
  end
  return ret
end

---@param func fun(element, index, array): any
function table:map(func)
  local ret = {}
  for i, v in ipairs(self) do
    table.insert(ret, func(v, i, self))
  end
  return ret
end

-- frequenly used filter & map functions
Util.IdMapper = function(e) return e.id end
Util.Id2CardMapper = function(id) return Fk:getCardById(id) end
Util.Id2PlayerMapper = function(id)
  return Fk:currentRoom():getPlayerById(id)
end
Util.NameMapper = function(e) return e.name end
Util.Name2GeneralMapper = function(e) return Fk.generals[e] end
Util.Name2SkillMapper = function(e) return Fk.skills[e] end

-- for card preset
Util.GlobalCanUse = function(self, player, card)
  local room = Fk:currentRoom()
  for _, p in ipairs(room.alive_players) do
    if not (card and player:isProhibited(p, card)) then
      return true
    end
  end
end

Util.AoeCanUse = function(self, player, card)
  local room = Fk:currentRoom()
  for _, p in ipairs(room.alive_players) do
    if p ~= player and not (card and player:isProhibited(p, card)) then
      return true
    end
  end
end

Util.GlobalOnUse = function(self, room, cardUseEvent)
  if not cardUseEvent.tos or #TargetGroup:getRealTargets(cardUseEvent.tos) == 0 then
    cardUseEvent.tos = {}
    for _, player in ipairs(room:getAlivePlayers()) do
      if not room:getPlayerById(cardUseEvent.from):isProhibited(player, cardUseEvent.card) then
        TargetGroup:pushTargets(cardUseEvent.tos, player.id)
      end
    end
  end
end

Util.AoeOnUse = function(self, room, cardUseEvent)
  if not cardUseEvent.tos or #TargetGroup:getRealTargets(cardUseEvent.tos) == 0 then
    cardUseEvent.tos = {}
    for _, player in ipairs(room:getOtherPlayers(room:getPlayerById(cardUseEvent.from))) do
      if not room:getPlayerById(cardUseEvent.from):isProhibited(player, cardUseEvent.card) then
        TargetGroup:pushTargets(cardUseEvent.tos, player.id)
      end
    end
  end
end

---@generic T
---@param self T[]
---@return T[]
function table.reverse(self)
  local ret = {}
  for _, e in ipairs(self) do
    table.insert(ret, 1, e)
  end
  return ret
end

function table:contains(element)
  if #self == 0 then return false end
  for _, e in ipairs(self) do
    if e == element then return true end
  end
end

function table:shuffle()
  if #self == 2 then
    if math.random() < 0.5 then
      self[1], self[2] = self[2], self[1]
    end
  else
    for i = #self, 2, -1 do
        local j = math.random(i)
        self[i], self[j] = self[j], self[i]
    end
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

-- similar to table.clone but not recursively
function table.simpleClone(self)
  local ret = {}
  for k, v in pairs(self) do
    ret[k] = v
  end
  return ret
end

-- similar to table.clone but not clone class/instances
function table.cloneWithoutClass(self)
  local ret = {}
  for k, v in pairs(self) do
    if type(v) == "table" then
      if v.class or v.super then
        ret[k] = v
      else
        ret[k] = table.cloneWithoutClass(v)
      end
    else
      ret[k] = v
    end
  end
  return ret
end

-- if table does not contain the element, we insert it
function table:insertIfNeed(element)
  if not table.contains(self, element) then
    table.insert(self, element)
  end
end

-- similar to table.insertTable but insertIfNeed inside
function table:insertTableIfNeed(list)
  for _, e in ipairs(list) do
    table.insertIfNeed(self, e)
  end
end

---@generic T
---@return T[]
function table.connect(...)
  local ret = {}
  for _, v in ipairs({...}) do
    table.insertTable(ret, v)
  end
  return ret
end

---@generic T
---@return T[]
function table.connectIfNeed(...)
  local ret = {}
  for _, v in ipairs({...}) do
    table.insertTableIfNeed(ret, v)
  end
  return ret
end

---@generic T
---@param self T[]
---@param n integer|nil
---@return T|T[]
function table:random(n)
  local n0 = n
  n = n or 1
  if #self == 0 then return n0 ~= nil and {} or nil end
  local tmp = {table.unpack(self)}
  local ret = {}
  while n > 0 and #tmp > 0 do
    local i = math.random(1, #tmp)
    table.insert(ret, table.remove(tmp, i))
    n = n - 1
  end
  return n0 == nil and ret[1] or ret
end

function table:slice(begin, _end)
  local len = #self
  begin = begin or 1
  _end = _end or len + 1

  if begin <= 0 then begin = len + 1 + begin end
  if _end <= 0 then _end = len + 1 + _end end
  if begin >= _end then return {} end

  local ret = {}
  for i = math.max(begin, 1), math.min(_end - 1, len), 1 do
    table.insert(ret, self[i])
  end
  return ret
end

function table:assign(targetTbl)
  for key, value in pairs(targetTbl) do
    if self[key] then
      if type(value) == "table" then
        table.insertTable(self[key], value)
      else
        table.insert(self[key], value)
      end
    else
      self[key] = value
    end
  end
end

function table.empty(t)
  return next(t) == nil
end

-- allow a = "Hello"; a[1] == "H"
local str_mt = getmetatable("")
str_mt.__index = function(str, k)
  if type(k) == "number" then
    if math.abs(k) > str:len() then
      error("string index out of range")
    end
    local start, _end
    if k > 0 then
      start, _end = utf8.offset(str, k), utf8.offset(str, k + 1)
    elseif k < 0 then
      local len = str:len()
      start, _end = utf8.offset(str, len + k + 1), utf8.offset(str, len + k + 2)
    else
      error("str[0] is undefined behavior")
    end
    return str:sub(start, _end - 1)
  end
  return string[k]
end

str_mt.__add = function(a, b)
  return a .. b
end

str_mt.__mul = function(a, b)
  return a:rep(b)
end

-- override default string.len
string.rawlen = string.len
---@diagnostic disable-next-line: duplicate-set-field
function string:len()
  return utf8.len(self)
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

function string:startsWith(start)
  return self:sub(1, #start) == start
end

function string:endsWith(e)
  return e == "" or self:sub(-#e) == e
end

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

os.getms = function() return fk.GetMicroSecond(fk) end

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
local TargetGroup = {}

function TargetGroup:getRealTargets(targetGroup)
  if not targetGroup then
    return {}
  end

  local realTargets = {}
  for _, targets in ipairs(targetGroup) do
    table.insert(realTargets, targets[1])
  end

  return realTargets
end

function TargetGroup:includeRealTargets(targetGroup, playerId)
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

function TargetGroup:removeTarget(targetGroup, playerId)
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

function TargetGroup:pushTargets(targetGroup, playerIds)
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
local AimGroup = {}

AimGroup.Undone = 1
AimGroup.Done = 2
AimGroup.Cancelled = 3

function AimGroup:initAimGroup(playerIds)
  return { [AimGroup.Undone] = playerIds, [AimGroup.Done] = {}, [AimGroup.Cancelled] = {} }
end

function AimGroup:getAllTargets(aimGroup)
  local targets = {}
  table.insertTable(targets, aimGroup[AimGroup.Undone])
  table.insertTable(targets, aimGroup[AimGroup.Done])
  return targets
end

function AimGroup:getUndoneOrDoneTargets(aimGroup, done)
  return done and aimGroup[AimGroup.Done] or aimGroup[AimGroup.Undone]
end

function AimGroup:setTargetDone(aimGroup, playerId)
  local index = table.indexOf(aimGroup[AimGroup.Undone], playerId)
  if index ~= -1 then
    table.remove(aimGroup[AimGroup.Undone], index)
    table.insert(aimGroup[AimGroup.Done], playerId)
  end
end

function AimGroup:addTargets(room, aimEvent, playerIds)
  local playerId = type(playerIds) == "table" and playerIds[1] or playerIds
  table.insert(aimEvent.tos[AimGroup.Undone], playerId)

  if type(playerIds) == "table" then
    for i = 2, #playerIds do
      aimEvent.subTargets = aimEvent.subTargets or {}
      table.insert(aimEvent.subTargets, playerIds[i])
    end
  end

  room:sortPlayersByAction(aimEvent.tos[AimGroup.Undone])
  if aimEvent.targetGroup then
    TargetGroup:pushTargets(aimEvent.targetGroup, playerIds)
  end
end

function AimGroup:cancelTarget(aimEvent, playerId)
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

function AimGroup:removeDeadTargets(room, aimEvent)
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

function AimGroup:getCancelledTargets(aimGroup)
  return aimGroup[AimGroup.Cancelled]
end

return { TargetGroup, AimGroup, Util }
