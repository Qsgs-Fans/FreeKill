--- 类似EventWrapper故事，里面的东西最终会mix到SmartAI中
---@class AIUtil
local AIUtil = {} -- mixin

--- 根据传入的牌ids 判断权重
---@param cards integer[]       @ 牌ids
---@param number integer        @ 需要弃置几张
---@param filter? fun(integer)  @ 条件判断 判断权重大于 或 小于 n
---@return integer[]            @ 牌ids
function AIUtil:getChoiceCardsByKeepValue(cards, number, filter)
  number = math.max(1, math.min(number, #cards))

  --- 根据每张牌的id 查找权重
  local list = {}
  for i, id in ipairs(cards) do
    local card = Fk:getCardById(id)
    local value = fk.ai_card_keep_value[card.name] or -50

    if (not filter) or filter(value) then
      table.insert(list, {id, value})
    end
  end

  --- 根据权重从低往高排序
  table.sort(list, function(a, b)
    return a[2] < b[2]
  end)

  --- 将排序后的card id返回
  local ret = {}
  for _, entry in ipairs(list) do
    table.insert(ret, entry[1])
    if #ret == number then break end  --- 一旦收集到足够的牌，就停止循环
  end

  return ret
end


return AIUtil
