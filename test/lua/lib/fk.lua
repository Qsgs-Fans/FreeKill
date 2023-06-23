-- 为纯lua的测试环境捏一个虚拟的fk以便于测试

local fk = {}

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

return fk
