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

function TestCard:testVirtualCardInfo()
  -- 测试印卡函数：关于在局内印card的二三事
  -- 在局内印卡会涉及到有可能对应实体牌（子卡）的虚拟牌
  -- 本测试主要测试子卡对虚拟牌的花色/点数的影响
  local cards = {1, 8, 24, 25, 32, 35}
  -- 杀 黑桃7
  -- 杀 梅花2
  -- 杀 红桃11
  -- 杀 方块6
  -- 闪 红桃2
  -- 闪 方块2
  local slash_vcard = Fk:cloneCard("slash")
  lu.assertEquals(slash_vcard.color, Card.NoColor)
  lu.assertEquals(slash_vcard.suit, Card.NoSuit)
  lu.assertEquals(slash_vcard.number, 0)

  slash_vcard:addSubcard(cards[1])
  lu.assertEquals(slash_vcard.suit, Card.Spade)
  lu.assertEquals(slash_vcard.number, 7)
  slash_vcard:addSubcard(cards[2])
  lu.assertEquals(slash_vcard.suit, Card.NoSuit)
  lu.assertEquals(slash_vcard.color, Card.Black)
  lu.assertEquals(slash_vcard.number, 0)
  slash_vcard:addSubcard(cards[3])
  lu.assertEquals(slash_vcard.color, Card.NoColor)

  local jink_vcard = Fk:cloneCard("jink")
  jink_vcard:addSubcard(cards[3])
  lu.assertEquals(jink_vcard.name, "jink")
  lu.assertEquals(jink_vcard.suit, Card.Heart)
  lu.assertEquals(jink_vcard.number, 11)
  jink_vcard:addSubcard(cards[5])
  lu.assertEquals(jink_vcard.suit, Card.NoSuit)
  lu.assertEquals(jink_vcard.number, 0)
  jink_vcard:addSubcard(cards[4])
  lu.assertEquals(jink_vcard.suit, Card.NoSuit)
  lu.assertEquals(jink_vcard.color, Card.Red)
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
