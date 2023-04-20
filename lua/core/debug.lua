-- SPDX-License-Identifier: GPL-3.0-or-later

---@diagnostic disable: lowercase-global
inspect = require "inspect"
dbg = require "debugger"

function p(v) print(inspect(v)) end
function pt(t) for k, v in pairs(t) do print(k, v) end end
