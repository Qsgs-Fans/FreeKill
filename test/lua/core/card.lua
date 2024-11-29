-- 针对 core/card.lua 的测试用例

TestCard = {}

function TestCard:setupClass()
  ClientInstance = AbstractRoom:new()
end

function TestCard:testInitialize()
  -- 测试构造函数：关于构造一张card
  -- 只有两种构造方式：Card:clone和Engine:cloneCard 前者用于加载阶段 后者通用
  -- 对前者取拓展包已有的牌测试 对于后者现场clone
  local slash = Fk:getCardById(1)
  local slash_vcard = Fk:cloneCard("slash")
  lu.assertNotIsTrue(slash:isVirtual())
  lu.assertIsTrue(slash_vcard:isVirtual())
end

-- 测试虚拟牌/转化牌的花色点数
function TestCard:testSuitAndNumber()
  local slash_spade_7 = Fk:getCardById(1, true)
  lu.assertEquals(slash_spade_7.suit, Card.Spade)
  lu.assertEquals(slash_spade_7.number, 7)
end

function TestCard:teardownClass()
  ClientInstance = nil
end
