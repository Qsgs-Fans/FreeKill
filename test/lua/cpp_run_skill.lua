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

-- 按luaUnit之礼，要把测试都整理出表并放入全局变量
for _, pname in ipairs(Fk.package_names) do
  local pack = Fk.packages[pname]
  local index_mt = { setup = FkTest.initRoom, tearDown = FkTest.clearRoom }
  for _, skel in ipairs(pack.skill_skels) do
    local testtab = setmetatable({}, { __index = index_mt })
    for i, fn in ipairs(skel.tests) do
      testtab[string.format('test%s%d', skel.name, i)] = function()
        local room = FkTest.room
        fn(room, room.players[1])
      end
    end
    local skill = Skill:new(skel.name)
    local glob_name = string.format('Test%s', skill.name)
    if _G[glob_name] then
      fk.qWarning(("Duplicated test table %s detected. Skipping it."):format(glob_name))
    else
      _G[glob_name] = testtab
    end
  end
end
