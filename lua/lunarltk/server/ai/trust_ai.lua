-- SPDX-License-Identifier: GPL-3.0-or-later

-- Trust AI
-- 需要打出牌时，有的话就打出
-- 需要使用闪、对自己使用无懈、酒、桃时，只要有就使用
-- 除此之外什么都不做

---@class TrustAI: AI
local TrustAI = AI:subclass("TrustAI")

function TrustAI:initialize(player)
  AI.initialize(self, player)
end

function TrustAI:handleAskForUseCard(data)
  local pattern = data[2]
  local prompt = data[3]

  local wontuse = true
  if pattern == "jink" then
    wontuse = false
  elseif pattern == "nullification" then
    wontuse = prompt:split(":")[3] ~= tostring(self.player.id)
  elseif pattern == "peach" or pattern == "peach,analeptic" then
    wontuse = not prompt:startsWith("#AskForPeachesSelf")
  end
  if wontuse then return "" end

  local cards = self:getEnabledCards()
  for _, cd in ipairs(cards) do
    self:selectCard(cd, true) -- 默认按下卡牌后直接可确定 懒得管了
    return self:doOKButton()
  end
  return ""
end

function TrustAI:handleAskForResponseCard(data)
  -- local cancelable = data[4] -- 算了，不按取消
  local cards = self:getEnabledCards()
  for _, cd in ipairs(cards) do
    self:selectCard(cd, true) -- 默认按下卡牌后直接可确定 懒得管了
    return self:doOKButton()
  end
  return ""
end

return TrustAI
