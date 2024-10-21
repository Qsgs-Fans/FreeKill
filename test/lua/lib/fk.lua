-- 为纯lua的测试环境捏一个虚拟的fk以便于测试

local fk = {}
local testFail = false

local json = require "lua.lib.json"

local os, io = os, io

-- 这下Linux专用了
function fk.QmlBackend_ls(dir)
  local f = io.popen("ls " .. dir)
  return f:read("*a"):split("\n")
end

function fk.QmlBackend_isDir(dir)
  local f = io.popen("if [ -d " .. dir .. " ]; then echo OK; fi")
  return f:read("*a"):sub(1, 2) == "OK"
end

function fk.QmlBackend_exists(dir)
  local f = io.popen("if [ -e " .. dir .. " ]; then echo OK; fi")
  return f:read("*a"):sub(1, 2) == "OK"
end

function fk.QmlBackend_pwd()
  local f = io.popen("pwd")
  return f:read("*a")
end

function fk.QmlBackend_cd(dir) end

function fk.QJsonDocument_fromVariant(e)
  return {
    toJson = function(_, __)
      return json.encode(e)
    end,
  }
end

function fk.QJsonDocument_fromJson(str)
  return {
    toVariant = function(_)
      return json.decode(str)
    end,
  }
end

function fk.GetDisabledPacks()
  return "[]"
  --[[
  local pkgs = fk.QmlBackend_ls("packages")
  table.removeOne(pkgs, "test")
  return json.encode(pkgs)
  --]]
end

function fk.qCritical(msg) print(string.char(27) .. "[91m[Test/C]" ..
  string.char(27) .. "[0m " .. msg); testFail = true end
function fk.qInfo(msg) print(string.char(27) .. "[95m[Test/I]" ..
  string.char(27) .. "[0m " .. msg) end
function fk.qWarning(msg) print(string.char(27) .. "[94m[Test/W]" ..
  string.char(27) .. "[0m " .. msg) end
function fk.qDebug(msg) print(string.char(27) .. "[90m[Test/D]" ..
  string.char(27) .. "[0m " .. msg) end

function fk.GetMicroSecond()
  return os.time() * 100000
end

function fk.roomtest(croom, f)
  local room = Room(croom)
  RoomInstance = room
  --room.action = function() f(room) end
  while true do
    local over = room:resume()
    if over then break else room.in_delay = false end
  end
  RoomInstance = nil
  local fail = testFail
  if fail then testFail = false end
  lu.assertFalse(fail, "Test failed!")
end

-- terminal color
fk.BOLD = string.char(27) .. "[1m"
fk.GRAY = string.char(27) .. "[90m"
fk.RED = string.char(27) .. "[91m"
fk.GREEN = string.char(27) .. "[92m"
fk.BLUE = string.char(27) .. "[94m"
fk.YELLOW = string.char(27) .. "[93m"
fk.DEEPBLUE = string.char(27) .. "[34m"
fk.PURPLE = string.char(27) .. "[95m"
fk.CYAN = string.char(27) .. "[96m"
fk.RST = string.char(27) .. "[0m"
fk.CARET = string.char(27) .. "[92m => ".. fk.RST

return fk
