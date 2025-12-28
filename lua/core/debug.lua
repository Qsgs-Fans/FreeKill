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

-- verbose设施，主要用于ai代码中性能分析和调试。

-- 0: 模拟UI的提示
-- 1:
local _verbose_level = -1

local colors = {
  BOLD = string.char(27) .. "[1m",
  GRAY = string.char(27) .. "[90m",
  RED = string.char(27) .. "[91m",
  GREEN = string.char(27) .. "[92m",
  BLUE = string.char(27) .. "[94m",
  YELLOW = string.char(27) .. "[93m",
  DEEPBLUE = string.char(27) .. "[34m",
  PURPLE = string.char(27) .. "[95m",
  CYAN = string.char(27) .. "[96m",
  RST = string.char(27) .. "[0m",
}
colors.CARET = string.char(27) .. "[92m => ".. colors.RST

local function colorConvert(log)
  -- 我真服了这些HTML颜色了 统一都用一个不行么
  log = log:gsub('<font color="#0598BC">', string.char(27) .. "[34m")
  log = log:gsub('<font color="#0C8F0C">', string.char(27) .. "[32m")
  log = log:gsub('<font color="#CC3131">', string.char(27) .. "[31m")
  log = log:gsub("<font color='#BE2020'>", string.char(27) .. "[31m")
  log = log:gsub('<font color="red">', string.char(27) .. "[31m")
  log = log:gsub('<font color="black">', string.char(27) .. "[0m")
  log = log:gsub('<font color="#0598BC">', string.char(27) .. "[34m")
  log = log:gsub('<font color="blue">', string.char(27) .. "[34m")
  log = log:gsub('<font color="#0C8F0C">', string.char(27) .. "[32m")
  log = log:gsub('<font color="green">', string.char(27) .. "[32m")
  log = log:gsub('<font color="#CC3131">', string.char(27) .. "[31m")
  log = log:gsub('<font color="#B5BA00">', string.char(27) .. "[33m")
  log = log:gsub('<font color="grey">', string.char(27) .. "[90m")
  log = log:gsub("<font color='grey'>", string.char(27) .. "[90m")
  log = log:gsub("<b>", colors.BOLD)
  log = log:gsub("</b></font>", colors.RST)
  log = log:gsub("</font>", colors.RST)
  log = log:gsub("<b>", colors.BOLD)
  log = log:gsub("</b>", colors.RST)

  log = log:gsub("<br>", "\n")
  log = log:gsub("<br/>", "\n")
  log = log:gsub("<br />", "\n")
  return log
end

---@param level integer
---@param fmt string
function verbose(level, fmt, ...)
  if _verbose_level > level then return end
  fmt = tostring(fmt)
  local str = fmt:format(...)
  print(("[%12.6f] %s"):format(os.clock(), colorConvert(str)))
end
