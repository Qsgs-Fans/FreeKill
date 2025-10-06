---@class Base.Player : Object
---@field public id integer @ 玩家的id，每名玩家的id是唯一的，为正数。机器人的id是负数。
---@field public role string @ 身份 涉及胜负结算
---@field public seat integer @ 座位号
---@field public next Base.Player @ 下家
---@field public mark table<string, any> @ 当前拥有的所有标记，键为标记名，值为标记值
local Player = class("Base.Player")

function Player:initialize()
  self.id = 0

  self.property_keys = {
    "seat", "role",
  }

  self.role = ""
  self.seat = 0
  self.next = nil
  self.mark = {}
end

--- 为角色```mark```增加```count```个。
--- 实践上通常直接使用包含通知客户端的```Room:addPlayerMark```
---@param mark string @ 标记
---@param count integer @ 为标记赋予的数量
function Player:addMark(mark, count)
  count = count or 1
  local num = self.mark[mark]
  num = num or 0
  self:setMark(mark, math.max(num + count, 0))
end

--- 为角色移除数个Mark。仅能用于数字型标记，且至多减至0
---@param mark string @ 标记
---@param count? integer @ 为标记删除的数量，默认1
function Player:removeMark(mark, count)
  count = count or 1
  local num = self.mark[mark]
  num = num or 0
  self:setMark(mark, math.max(num - count, 0))
end

--- 为角色设置Mark至指定数量。
-- mark name and UI:
--
-- ```xxx```: invisible mark
--
-- ```@xxx```: mark with extra data (maybe string or number)
--
-- ```@@xxx```: mark with invisible extra data
--
-- ```@$xxx```: mark with card_name[] or card_integer[] data
--
-- ```@&xxx```: mark with general_name[] data
---@param mark string @ 标记
---@param count? any @ 标记要设定的数量
function Player:setMark(mark, count)
  if count == 0 then count = nil end
  if self.mark[mark] ~= count then
    self.mark[mark] = count
  end
end

--- 获取角色对应Mark的数量。注意初始为0
---@param name string @ 标记
---@return any
function Player:getMark(name)
  local mark = self.mark[name]
  if not mark then return 0 end
  if type(mark) == "table" and not Util.isCborObject(mark) then
    return table.simpleClone(mark)
  end
  return mark
end

--- 获取角色对应Mark并初始化为table
---@param name string @ 标记
---@return table
function Player:getTableMark(name)
  local mark = self.mark[name]
  if type(mark) == "table" then return table.simpleClone(mark) end
  return {}
end

--- 获取角色有哪些Mark。
---@return string[]
function Player:getMarkNames()
  local ret = {}
  for k, _ in pairs(self.mark) do
    table.insert(ret, k)
  end
  return ret
end

--- 检索角色是否拥有指定Mark，考虑后缀(find)。返回检索到的的第一个标记名与标记值
---@param mark string @ 标记名
---@param suffixes? string[] @ 后缀，默认为```MarkEnum.TempMarkSuffix```
---@return [string, any]|nil @ 返回一个表，包含标记名与标记值，或nil
function Player:hasMark(mark, suffixes)
  if suffixes == nil then suffixes = MarkEnum.TempMarkSuffix end
  for m, _ in pairs(self.mark) do
    if m == mark then return {self.mark[m], m} end
    if m:startsWith(mark .. "-") then
      for _, suffix in ipairs(suffixes) do
        if m:find(suffix, 1, true) then return {self.mark[m], m} end
      end
    end
  end
  return nil
end

-- 底层逻辑之序列化

function Player:serialize()
  local ptable = {}
  for _, k in ipairs(self.property_keys) do
    ptable[k] = self[k]
  end

  return {
    properties = ptable,

    mark = cbor.encode(self.mark),
  }
end

function Player:deserialize(o)
  for k, v in pairs(o.properties) do self[k] = v end

  self.mark = cbor.decode(o.mark)
end

return Player
