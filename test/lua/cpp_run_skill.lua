-- Run tests with `ctest`
-- 本测试加载并运行和游戏逻辑有关的测试。
-- 测试途中应保证：
-- * 不能让房间切出，房间只能以gameOver形式结束运行。
-- * 也就是说，要屏蔽掉__handleRequest型的yield。

---@diagnostic disable: lowercase-global
--@diagnostic disable: undefined-global

__package.path = __package.path .. ";./test/lua/lib/?.lua"

fk.os = __os
fk.io = __io
lu = require('luaunit')
require 'fake_backend'

fk.qInfo = Util.DummyFunc
-- 给各种extensionName文件夹下的init
for _, dir in ipairs(Fk.extension_names) do
  local path = "packages/" .. dir
  -- 耦！
  if UsingNewCore and table.contains({ "standard", "standard_cards", "maneuvering" }, dir) then
    path = "packages/freekill-core/" .. dir
  end
  if FileIO.isDir(path .. "/test") then
    local files = table.filter(FileIO.ls(path .. "/test"), function(s)
      return not not s:find("test_.*.lua")
    end)
    for _, f in ipairs(files) do
      dofile(path .. "/test/" .. f)
    end
  end
end
