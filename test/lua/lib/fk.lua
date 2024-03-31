-- 为纯lua的测试环境捏一个虚拟的fk以便于测试

local fk = {}
local testFail = false

local os, io = os, io

-- 这下Linux专用了
function fk.QmlBackend_ls(dir)
  local f = io.popen("ls " .. dir)
  return f:read("*a"):split("\n")
end

function fk.QmlBackend_isDir(dir)
  local f = io.popen("if [ -d " .. dir .. " ]; then echo OK; fi")
  return f:read("*a"):startsWith("OK")
end

function fk.QmlBackend_exists(dir)
  local f = io.popen("if [ -e " .. dir .. " ]; then echo OK; fi")
  return f:read("*a"):startsWith("OK")
end

function fk.GetDisabledPacks()
  local pkgs = fk.QmlBackend_ls("packages")
  table.removeOne(pkgs, "test")
  return json.encode(pkgs)
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
  room.action = function() f(room) end
  room:resume()
  RoomInstance = nil
  local fail = testFail
  if fail then testFail = false end
  lu.assertFalse(fail, "Test failed!")
end

return fk
