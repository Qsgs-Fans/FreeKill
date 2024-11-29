-- 针对 core/exppattern.lua 的测试用例
-- 别忘了先构造好了Fk之后再开测的
-- 基本上，每个API函数都要进行比较详尽的测试 也就是拓展会用到的方法

TestEngine = {}

function TestEngine:setupClass()
  -- 为currentRoom随便造个空白房
  ClientInstance = AbstractRoom:new()
end

function TestEngine:testInitialize()
  lu.assertIsTrue(Fk and Fk:isInstanceOf(Engine))
end

function TestEngine:testLoadPackages()
  -- 在跑这个测试时，应该只加载了三个核心包和test包
  lu.assertEquals(Fk.extension_names, { "standard", "standard_cards", "maneuvering", "test" })
  lu.assertEquals(Fk.package_names, { "standard", "standard_cards", "maneuvering", "test_p_0" })
end

function TestEngine:testTranslate()
  lu.assertEquals(Fk:translate("caocao"), "曹操")
end

function TestEngine:teardownClass()
  ClientInstance = nil
end
