-- SPDX-License-Identifier: GPL-3.0-or-later

---@diagnostic disable: lowercase-global
inspect = require "inspect"

DebugMode = true
function PrintWhenMethodCall()
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
--debug.sethook(PrintWhenMethodCall, "c")

function p(v) print(inspect(v)) end
function pt(t) for k,v in pairs(t)do print(k,v) end end
