-- SPDX-License-Identifier: GPL-3.0-or-later

local Util = {}
Util.DummyFunc = function() end
Util.TrueFunc = function() return true end
Util.FalseFunc = function() return false end
Util.DummyTable = setmetatable({}, {
  __newindex = function() error("Cannot assign to dummy table") end
})
Util.array2hash = function(t)
  local ret = {}
  for _, e in ipairs(t) do
    ret[e] = true
  end
  return ret
end

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

-- 是否是可以被编解码成cbor tagged的
Util.isCborObject = function(v)
  if type(v) ~= "table" then return false end
  local mt = getmetatable(v)
  return mt and mt.__tocbor ~= nil
end

---@param value integer
---@return string
---@overload fun(value: string): integer
function Util.convertSubtypeAndEquipSlot(value)
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

--- 根据花色文字描述（如 黑桃、红桃、梅花、方块）或者符号（如♠♥♣♦，带颜色）返回花色ID。
---@param symbol string @ 描述/符号（原文，确保没被翻译过）
---@return Suit @ 花色ID
Util.getSuitFromString = function(symbol)
  assert(type(symbol) == "string")
  if symbol:find("spade") then
    return Card.Spade
  elseif symbol:find("heart") then
    return Card.Heart
  elseif symbol:find("club") then
    return Card.Club
  elseif symbol:find("diamond") then
    return Card.Diamond
  else
    return Card.NoSuit
  end
end

--- 令移动原因字符串化
---@param item CardMoveReason @ 移动方式枚举
---@return string @ 移动方式字符串
---@diagnostic disable-next-line
function Util.moveReasonMapper(item) end

--- 将字符串转为移动原因枚举
---@param item string @ 移动方式字符串
---@return CardMoveReason? @ 移动方式枚举
---@diagnostic disable-next-line
Util.moveReasonMapper = function(item)
  local moveMapper = {
    ["reason_justmove"] = fk.ReasonJustMove,
    ["reason_draw"] = fk.ReasonDraw,
    ["reason_discard"] = fk.ReasonDiscard,
    ["reason_give"] = fk.ReasonGive,
    ["reason_put"] = fk.ReasonPut,
    ["reason_put_in_discard"] = fk.ReasonPutIntoDiscardPile,
    ["reason_use"] = fk.ReasonUse,
    ["reason_response"] = fk.ReasonResponse,
    ["reason_judge"] = fk.ReasonJudge,
    ["reason_recast"] = fk.ReasonRecast,
    ["reason_pindian"] = fk.ReasonPindian,
  }
  if type(item) == "string" then
    return moveMapper[item] or fk.ReasonJustMove
  else
    for k, v in pairs(moveMapper) do
      ---@diagnostic disable-next-line
      if v == item then return k end
    end
  end
end

---@diagnostic disable-next-line: lowercase-global
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

--- 用于for循环的迭代函数。可以将表按照某种权值的顺序进行遍历，这样不用进行完整排序。
---@generic T
---@param t T[]
---@param val_func? fun(e: T): integer @ 计算权值的函数，对int[]可不写
---@param reverse? boolean @ 是否反排？反排的话优先返回权值小的元素
function fk.sorted_pairs(t, val_func, reverse)
  local t2 = table.simpleClone(t)  -- 克隆一次表，用作迭代器上值
  local t_vals = table.map(t2, val_func or function(e) return e end)
  local iter = function()
    local max_idx, max, max_val = -1, nil, nil
    for i, v in ipairs(t2) do
      if not max then
        max_idx, max, max_val = i, v, t_vals[i]
      else
        local val = t_vals[i]
        local checked = val > max_val
        if reverse then checked = not checked end
        if checked then
          max_idx, max, max_val = i, v, val
        end
      end
    end
    if max_idx == -1 then return nil, nil end
    table.remove(t2, max_idx)
    table.remove(t_vals, max_idx)
    return -1, max, max_val
  end
  return iter, nil, 1
end

-- frequenly used filter & map functions

--- 返回ID
---@return integer
Util.IdMapper = function(e) return e.id end
--- 根据卡牌ID返回卡牌
Util.Id2CardMapper = function(id) return Fk:getCardById(id) end
--- 根据玩家ID返回玩家
Util.Id2PlayerMapper = function(id)
  return Fk:currentRoom():getPlayerById(id)
end
--- 返回名称
---@return string
Util.NameMapper = function(e) return e.name end
--- 根据武将名返回武将
Util.Name2GeneralMapper = function(e) return Fk.generals[e] end
--- 根据技能名返回技能
Util.Name2SkillMapper = function(e) return Fk.skills[e] end
--- 返回译文
Util.TranslateMapper = function(str) return Fk:translate(str) end

-- 阶段int型和string型互换
---@param phase integer
---@return string
---@overload fun(phase: string): integer
function Util.PhaseStrMapper(phase)
  local phase_table = {
    [Player.RoundStart] = "phase_roundstart",
    [Player.Start] = "phase_start",
    [Player.Judge] = "phase_judge",
    [Player.Draw] = "phase_draw",
    [Player.Play] = "phase_play",
    [Player.Discard] = "phase_discard",
    [Player.Finish] = "phase_finish",
    [Player.NotActive] = "phase_notactive",
    [Player.PhaseNone] = "phase_phasenone",
  }
  return type(phase) == "string" and table.indexOf(phase_table, phase) or phase_table[phase]
end

-- for card preset

--- 指定目标卡牌的targetFilter
---@param skill CardSkill @ 使用牌的CardSkill
---@param to_select Player @ 目标
---@param selected Player[] @ 已选目标
---@param selected_cards integer[] @ 牌的子表
---@param card Card @ 使用的卡牌
---@param extra_data any? @ 额外数据
---@param player Player @ 使用者
Util.CardTargetFilter = function(skill, player, to_select, selected, selected_cards, card, extra_data)
  if not skill:modTargetFilter(player, to_select, selected, card, extra_data) then return end
  local max_target_num = skill:getMaxTargetNum(player, card)
  if max_target_num > 0 and #selected >= max_target_num then return end
  if player:isProhibited(to_select, card) then return end
  extra_data = extra_data or {}
  if extra_data.must_targets then
    -- must_targets: 必须先选择must_targets内的**所有**目标
    if not (#extra_data.must_targets <= #selected or
      table.contains(extra_data.must_targets, to_select.id)) then return false end
  end
  if extra_data.include_targets then
    -- include_targets: 必须先选择include_targets内的**其中一个**目标
    if not (table.hasIntersection(extra_data.include_targets, selected) or
      table.contains(extra_data.include_targets, to_select.id)) then return false end
  end
  if extra_data.exclusive_targets then
    -- exclusive_targets: **只能选择**exclusive_targets内的目标
    if not table.contains(extra_data.exclusive_targets, to_select.id) then return false end
  end
  return true
end

--- 全局卡牌(包括自己)的canUse
Util.GlobalCanUse = function(self, player, card)
  local room = Fk:currentRoom()
  for _, p in ipairs(room.alive_players) do
    if not (card and player:isProhibited(p, card)) then
      return true
    end
  end
end

--- 默认对自己使用牌的canUse（如桃酒无中装备闪电）
---@param self ActiveSkill
---@param player Player
---@param card Card
---@param extra_data table?
Util.CanUseToSelf = function(self, player, card, extra_data)
  local tos = card:getFixedTargets(player, extra_data)
  return tos and table.find(tos, function(p)
    return not player:isProhibited(p, card)
    and Util.CardTargetFilter(self, player, p, {}, card.subcards, card, extra_data)
  end) ~= nil
end

--- AOE卡牌(不包括自己)的canUse
Util.AoeCanUse = function(self, player, card)
  for _, p in ipairs(Fk:currentRoom().alive_players) do
    if p ~= player and not (card and player:isProhibited(p, card)) then
      return true
    end
  end
end

--- 全局卡牌的onUse
---@param cardUseEvent UseCardData
Util.AoeCardOnUse = function(self, player, cardUseEvent, include_self)
  if not cardUseEvent.tos or #cardUseEvent.tos == 0 then
    cardUseEvent.tos = {}
    local players = table.simpleClone(Fk:currentRoom().alive_players) --[[ @as ServerPlayer[] ]]
    if not include_self then
      table.removeOne(players, player)
    end
    for _, p in ipairs(players) do
      if not player:isProhibited(p, cardUseEvent.card) then
        cardUseEvent:addTarget(p)
      end
    end
  end
end

-- Table

---@generic T
---@param self T[]
---@param func fun(element: T, index: integer, array: T[])
function table.forEach(self, func)
  for i, v in ipairs(self) do
    func(v, i, self)
  end
end

---@generic T
---@param self T[]
---@param func fun(element: T, index: integer, array: T[]): boolean?
---@return boolean
function table.every(self, func)
  for i, v in ipairs(self) do
    if not func(v, i, self) then
      return false
    end
  end
  return true
end

---@generic T
---@param self T[]
---@param func fun(element: T, index: integer, array: T[]): boolean?
---@return T?
function table.find(self, func)
  for i, v in ipairs(self) do
    if func(v, i, self) then
      return v
    end
  end
  return nil
end

---@generic T
---@param self T[]
---@param func fun(element: T, index: integer, array: T[]): boolean?
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

---@generic T, T2
---@param self T[]
---@param func fun(element: T, index: integer, array: T[]): T2
---@return T2[]
function table.map(self, func)
  local ret = {}
  for i, v in ipairs(self) do
    table.insert(ret, func(v, i, self))
  end
  return ret
end

--- 归约一个表的所有内容到一个变量
---@generic T, T2
---@param self T[] @ 要被归约的表
---@param init T2 @ 初始值
---@param func fun(result: T2, element: T, last_element: T?): T2 @ 循环调用函数
---@return T2
function table.reduce(self, init, func)
  if #self == 0 then return init end
  if #self == 1 then return func(init, self[1]) end

  local ret = init
  local last_element
  for _, v in ipairs(self) do
    ret = func(ret, v, last_element)
    last_element = v
  end
  return ret
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

---@generic T
---@param self T[]
---@return boolean
function table.contains(self, element)
  if #self == 0 then return false end
  for _, e in ipairs(self) do
    if e == element then return true end
  end
  return false
end

---@generic T
---@param self T[]
function table.shuffle(self)
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

---@generic T
---@param self T[]
---@param list T[]
function table.insertTable(self, list)
  for _, e in ipairs(list) do
    table.insert(self, e)
  end
end

---@generic T
---@param self T[]
---@param value T
---@param from? integer
---@return integer
function table.indexOf(self, value, from)
  from = from or 1
  for i = from, #self do
    if self[i] == value then return i end
  end
  return -1
end

---@generic T
---@param self T[]
---@param element T
---@return boolean
function table.removeOne(self, element)
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
---@generic T
---@param self T
---@return T
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
---@generic T
---@param self T[]
---@param element T
---@return boolean
function table.insertIfNeed(self, element)
  if not table.contains(self, element) then
    table.insert(self, element)
    return true
  end
  return false
end

-- similar to table.insertTable but insertIfNeed inside
---@generic T
---@param self T[]
---@param list T[]
function table.insertTableIfNeed(self, list)
  for _, e in ipairs(list) do
    table.insertIfNeed(self, e)
  end
end

---@generic T
---@param ... T
---@return T
function table.connect(...)
  local ret = {}
  for _, v in ipairs({...}) do
    table.insertTable(ret, v)
  end
  return ret
end

---@generic T
---@param ... T
---@return T
function table.connectIfNeed(...)
  local ret = {}
  for _, v in ipairs({...}) do
    table.insertTableIfNeed(ret, v)
  end
  return ret
end

---@generic T
---@param self T[]
---@return T
---@diagnostic disable-next-line
function table.random(self) end

---@generic T
---@param self T[]
---@param n integer
---@return T[]
---@diagnostic disable-next-line: duplicate-set-field
function table.random(self, n)
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

--- 截取[begin, end)段（end是开区间）
---@generic T
---@param self T[]
---@param begin? integer
---@param _end? integer
---@return T[]
function table.slice(self, begin, _end)
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

---@generic T, T2
---@param self table<T, T2> @ 要被赋值的表
---@param source table<T, T2> @ 赋值来源的表
function table.assign(self, source)
  for key, value in pairs(source) do
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

---@generic T
---@param self T[]
---@param other T[]
---@return boolean
function table.isEqual(self, other)
  if #self ~= #other then return false end
  local tabledup = table.simpleClone(other)
  for _, j in ipairs(self) do
    if not table.removeOne(tabledup, j) then return false end
  end
  return #tabledup == 0
end

---@generic T
---@param self T[]
---@param tbl T[]
function table.hasIntersection(self, tbl)
  local hash = {}
  for _, value in ipairs(self) do
    hash[value] = true
  end
  for _, value in ipairs(tbl) do
    if hash[value] then return true end
  end
  return false
end

---@param t table
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

---@param self string
---@diagnostic disable-next-line: duplicate-set-field
function string:len()
  return utf8.len(self)
end

---@param self string
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

---@param self string
function string:startsWith(start)
  return self:sub(1, #start) == start
end

---@param self string
function string:endsWith(e)
  return e == "" or self:sub(-#e) == e
end

FileIO = {
  pwd = fk.QmlBackend_pwd,

  ---@return string[]
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
  local ret = self.t[self.p + 1]
  self.t[self.p + 1] = nil
  return ret
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
return Util
