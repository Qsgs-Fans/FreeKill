-- SPDX-License-Identifier: GPL-3.0-or-later

---@diagnostic disable: lowercase-global
inspect = require "inspect"
dbg = require "debugger"

function PrintWhere()
  local info = debug.getinfo(2)
  local name = info.name
  local line = info.currentline
  local namewhat = info.namewhat
  local shortsrc = info.short_src
  if (namewhat == "method") and
    (shortsrc ~= "[C]") and
    (not string.find(shortsrc, "/lib")) then
    print(shortsrc .. ":" .. line .. ": " .. name)
  end
end
--debug.sethook(PrintWhere, "l")

function Traceback()
  print(debug.traceback())
end

local msgh = function(err)
  fk.qCritical(tostring(err) .. "\n" .. debug.traceback(nil, 2))
end

function Pcall(f, ...)
  local ret = { xpcall(f, msgh, ...) }
  local err = table.remove(ret, 1)
  if err ~= false then
    return table.unpack(ret)
  end
end

function p(v) print(inspect(v)) end
function pt(t) for k, v in pairs(t) do print(k, v) end end

-- 0: 模拟UI的提示
-- 1:
local _verbose_level = 999

---@param level integer
---@param fmt string
function verbose(level, fmt, ...)
  if _verbose_level > level then return end
  fmt = tostring(fmt)
  local str = fmt:format(...)
  print(("[%12.6f] %s"):format(os.clock(), str))
end
