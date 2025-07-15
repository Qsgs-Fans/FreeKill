--- 类似EventWrapper故事，里面的东西最终会mix到SmartAI中
---@class AIUtil
local AIUtil = {} -- mixin

--- 判断牌的保留权重，从低到高排
---@param cards integer[]       @ 牌ids
---@param number integer        @ 需要几张
---@param filter? fun(integer): boolean  @ 条件过滤 判断权重大于 或 小于 n
---@return integer[]            @ 牌ids
function AIUtil:getChoiceCardsByKeepValue(cards, number, filter)
  assert(number > 0 and number <= #cards, "number must be between 1 and #cards")

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
  for i, entry in ipairs(list) do
    table.insert(ret, entry[1])
    if i == number then break end  --- 一旦收集到足够的牌，就停止循环
  end

  return ret
end

---@class AIAskToChoosePlayersParams: AskToUseActiveSkillParams
---@field min_num integer @ 最小值
---@field max_num integer @ 最大值
---@field targets ServerPlayer[] @ 可以选的目标范围
---@field skill_name string @ 请求发动的技能名
---@field cancelable? boolean @ 是否可以点取消
---@field strategy_data any? @ 一些简易策略，表示选择角色将用来执行何种操作

--- 令AI askToChoosePlayers
---@param player SmartAI @ 要做选择的AI
---@param params AIAskToChoosePlayersParams @ 各种变量
---@return ServerPlayer[] @ 选择的玩家列表，可能为空
function AIUtil:askToChoosePlayers(player, params)
  local maxNum, minNum, targets = params.max_num, params.min_num, params.targets
  if maxNum < 1 or #targets == 0 then
    return {}
  end
  local skill_name = params.skill_name
  local cancelable = (params.cancelable == nil) and true or params.cancelable
  local data = params.strategy_data
  if data == nil then
    if cancelable then
      return {}
    else
      return table.random(targets, minNum)
    end
  else
    if data.strategy_type == "discard" then
    elseif data.strategy_type == "prey_card" then
    elseif data.strategy_type == "damage" then
    elseif data.strategy_type == "recover" then
    end
  end
end


return AIUtil
