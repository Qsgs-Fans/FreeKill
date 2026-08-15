-- xoshiro256**，一种伪随机数生成算法
-- 这也是Lua 5.4自带的math.random使用的算法。
--
-- 本文件是相同算法的纯Lua 5.4实现，但是可以自己创建随机数状态
-- 这样可以摆脱Lua的全局随机数生成状态，以便基于相同的种子进行随机序列复盘。

local function rotl(x, k)
  return (x << k) | (x >> (64 - k))
end

local function next(s)
  local s1 = s[1]
  local s2 = s[2]
  local s3 = s[3] ~ s1
  local s4 = s[4] ~ s2
  local result = rotl(s2 * 5, 7) * 9
  s[1] = s1 ~ s4
  s[2] = s2 ~ s3
  s[3] = s3 ~ (s2 << 17)
  s[4] = rotl(s4, 45)
  return result
end

local FIGS = 53
local shift64_FIG = 64 - FIGS
local scaleFIG = 0.5 / (1 << (FIGS - 1))

local function intToDouble(x)
  local sx = x >> shift64_FIG
  local res = sx * scaleFIG
  if sx < 0 then
    res = res + 1.0
  end
  return res
end

local function setseed(s, n1, n2)
  n2 = n2 or 0
  s[1] = n1
  s[2] = 0xff    -- avoid a zero state
  s[3] = n2
  s[4] = 0

  -- discard initial values to "spread" seed
  for _ = 0, 15 do next(s) end

  return n1, n2
end

-- 将x投影到[0, n]
local function project(s, x, n)
  -- 若为2^n-1则位运算
  if (n & (n + 1)) == 0 then
    return x & n
  end

  local lim = n
  -- compute the smallest (2~b - 1) not smaller than 'n'
  lim = lim | (lim >> 1)
  lim = lim | (lim >> 2)
  lim = lim | (lim >> 4)
  lim = lim | (lim >> 8)
  lim = lim | (lim >> 16)
  lim = lim | (lim >> 32);
  assert((lim & (lim + 1)) == 0  -- 'lim + 1' is a power of 2,
    and lim >= n  -- not smaller than 'n',
    and (lim >> 1) < n)  -- and it is the smallest one

  while true do
    -- project 'ran' into [0..lim]
    x = x & lim
    if (x <= n) then break end
    x = next(s) -- not inside [0..n]? try again
  end

  return x
end

local function random(s, m, n)
  local low, up
  local ret = next(s)
  if m == nil then
    return intToDouble(ret)
  elseif n == nil then
    low = 1
    up = m
    if up == 0 then return ret end
  else
    low = m
    up = n
  end

  assert(low <= up, "interval is empty")
  local p = project(s, ret, up - low)
  return p + low
end

local klass = {}

-- 可重新初始化随机种子。参见math.randomseed
function klass:randomseed(n1, n2)
  if n1 == nil then
    n1 = math.random(math.maxinteger)
    n2 = math.random(os.time())
  end

  setseed(self, n1, n2)
end

-- 生成伪随机数。与math.random行为一致。
--
-- - 无参数：生成[0,1)区间一致分布的伪随机浮点数
-- - 只指定m：生成[1,m]区间内一致分布的伪随机整数
-- - 指定m和n：生成[m,n]区间内一致分布的伪随机整数
function klass:random(m, n)
  return random(self, m, n)
end

-- 创建伪随机发生器并可初始化种子。参见math.randomseed
local function newGenerator(x, y)
  local ret = setmetatable({}, { __index = klass })
  ret:randomseed(x, y)
  return ret
end

return newGenerator
